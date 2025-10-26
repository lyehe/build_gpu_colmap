import datetime

import cv2
import h5py
import numpy as np
import poselib
import pycolmap
from tqdm import tqdm

import posebench
from posebench.utils.geometry import (
    angle,
    calibrate_pts,
    eigen_quat_to_wxyz,
    essential_from_pose,
    qvec2rotmat,
    rotation_angle,
    sampson_error,
)
from posebench.utils.misc import (
    camera_dict_to_calib_matrix,
    compute_auc,
    h5_to_camera_dict,
    poselib_opt_to_pycolmap_opt,
    substr_in_list,
)


# Compute metrics for relative pose estimation
# AUC for max(err_R,err_t) and avg/med for runtime
def compute_metrics(results, thresholds=[5.0, 10.0, 20.0]):
    methods = results.keys()
    metrics = {}
    for m in methods:
        max_err = [np.max((a, b)) for (a, b) in results[m]["errs"]]
        metrics[m] = {}
        aucs = compute_auc(max_err, thresholds)
        for auc, t in zip(aucs, thresholds):
            metrics[m][f"AUC{int(t)}"] = auc
        metrics[m]["avg_rt"] = np.mean(results[m]["runtime"])
        metrics[m]["med_rt"] = np.median(results[m]["runtime"])

    return metrics


def eval_essential_estimator(instance, estimator="poselib"):
    opt = instance["opt"]
    if estimator == "poselib":
        tt1 = datetime.datetime.now()
        pose, info = poselib.estimate_relative_pose(
            instance["x1"], instance["x2"], instance["cam1"], instance["cam2"], opt, {}
        )
        tt2 = datetime.datetime.now()
        (R, t) = (pose.R, pose.t)
    elif estimator == "pycolmap":
        opt = poselib_opt_to_pycolmap_opt(opt)
        tt1 = datetime.datetime.now()
        result = pycolmap.estimate_essential_matrix(
            instance["x1"], instance["x2"], instance["cam1"], instance["cam2"], opt
        )
        tt2 = datetime.datetime.now()

        if result is not None:
            R = qvec2rotmat(eigen_quat_to_wxyz(result["cam2_from_cam1"].rotation.quat))
            t = result["cam2_from_cam1"].translation
        else:
            R = np.eye(3)
            t = np.zeros(3)
    else:
        raise Exception("nyi")

    err_R = rotation_angle(instance["R"] @ R.T)
    err_t = angle(instance["t"], t)

    return [err_R, err_t], (tt2 - tt1).total_seconds()


def eval_essential_refinement(instance):
    x1 = instance["x1"]
    x2 = instance["x2"]
    cam1 = instance["cam1"]
    cam2 = instance["cam2"]
    K1 = camera_dict_to_calib_matrix(cam1)
    K2 = camera_dict_to_calib_matrix(cam2)

    R_gt = instance["R"]
    t_gt = instance["t"]
    E_gt = essential_from_pose(R_gt, t_gt)
    F_gt = np.linalg.inv(K2.T) @ E_gt @ np.linalg.inv(K1)
    samp_err = sampson_error(F_gt, x1, x2)
    # TODO compute tangent sampson error here

    threshold = instance["threshold"]
    inl = samp_err < threshold

    init_pose = poselib.CameraPose()
    init_pose.R = R_gt
    init_pose.t = t_gt

    tt1 = datetime.datetime.now()
    pose, info = poselib.refine_relative_pose(
        x1[inl], x2[inl], init_pose, cam1, cam2, {}
    )
    tt2 = datetime.datetime.now()

    err_R = rotation_angle(R_gt @ pose.R.T)
    err_t = angle(t_gt, pose.t)

    return [err_R, err_t], (tt2 - tt1).total_seconds()


def eval_fundamental_estimator(instance, estimator="poselib"):
    opt = instance["opt"]
    if estimator == "poselib":
        tt1 = datetime.datetime.now()
        F, info = poselib.estimate_fundamental(instance["x1"], instance["x2"], opt, {})
        tt2 = datetime.datetime.now()
        inl = info["inliers"]
    elif estimator == "pycolmap":
        opt = poselib_opt_to_pycolmap_opt(opt)
        tt1 = datetime.datetime.now()
        result = pycolmap.estimate_fundamental_matrix(
            instance["x1"], instance["x2"], opt
        )
        tt2 = datetime.datetime.now()
        if result is None or "F" not in result:
            return [180.0, 180.0], (tt2 - tt1).total_seconds()
        F = result["F"]
        # newer pycolmap seemingly uses 'inlier_mask' instead of 'inliers'
        inl = result["inliers"] if "inliers" in result else result["inlier_mask"]
    else:
        raise Exception("nyi")

    K1 = camera_dict_to_calib_matrix(instance["cam1"])
    K2 = camera_dict_to_calib_matrix(instance["cam2"])
    if np.sum(inl) < 5:
        return [180.0, 180.0], (tt2 - tt1).total_seconds()

    E = K2.T @ F @ K1
    x1i = calibrate_pts(instance["x1"][inl], K1)
    x2i = calibrate_pts(instance["x2"][inl], K2)

    _, R, t, good = cv2.recoverPose(E, x1i, x2i)
    err_R = rotation_angle(instance["R"] @ R.T)
    err_t = angle(instance["t"], t)

    return [err_R, err_t], (tt2 - tt1).total_seconds()


def eval_fundamental_refinement(instance):
    return [0.0], 0.0


def main(
    dataset_path="data/relative",
    force_opt={},
    dataset_filter=[],
    method_filter=[],
    subsample=None,
):
    datasets = [
        # ('fisheye_grossmunster_4342', 1.0),
        # ('fisheye_kirchenge_2731', 1.0),
        ("megadepth1500_sift", 1.0),
        ("megadepth1500_spsg", 1.0),
        ("megadepth1500_splg", 1.0),
        ("megadepth1500_roma", 1.0),
        ("megadepth1500_dkm", 1.0),
        ("megadepth1500_aspanformer", 1.0),
        ("scannet1500_sift", 1.5),
        ("scannet1500_spsg", 1.5),
        ("scannet1500_roma", 2.5),
        ("scannet1500_dkm", 2.5),
        ("scannet1500_aspanformer", 2.5),
        ("imc_british_museum", 0.75),
        ("imc_london_bridge", 0.75),
        ("imc_piazza_san_marco", 0.75),
        ("imc_florence_cathedral_side", 0.75),
        ("imc_milan_cathedral", 0.75),
        ("imc_sagrada_familia", 0.75),
        ("imc_lincoln_memorial_statue", 0.75),
        ("imc_mount_rushmore", 0.75),
        ("imc_st_pauls_cathedral", 0.75),
    ]
    if len(dataset_filter) > 0:
        datasets = [(n, t) for (n, t) in datasets if substr_in_list(n, dataset_filter)]

    evaluators = {
        "E (poselib)": lambda i: eval_essential_estimator(i, estimator="poselib"),
        "E (COLMAP)": lambda i: eval_essential_estimator(i, estimator="pycolmap"),
        "F (poselib)": lambda i: eval_fundamental_estimator(i, estimator="poselib"),
        "F (COLMAP)": lambda i: eval_fundamental_estimator(i, estimator="pycolmap"),
    }
    if len(method_filter) > 0:
        evaluators = {
            k: v for (k, v) in evaluators.items() if substr_in_list(k, method_filter)
        }

    metrics = {}
    full_results = {}
    for dataset, threshold in datasets:
        f = h5py.File(f"{dataset_path}/{dataset}.h5", "r")

        opt = {
            "max_reproj_error": threshold,
            "max_epipolar_error": threshold,
            "max_iterations": 1000,
            "min_iterations": 100,
            "success_prob": 0.9999,
        }

        for k, v in force_opt.items():
            opt[k] = v

        results = {}
        for k in evaluators.keys():
            results[k] = {"errs": [], "runtime": []}
        data = list(f.items())
        if subsample is not None:
            print(
                f"Subsampling {len(data)} instances to {len(data) // subsample} instances"
            )
            data = data[::subsample]

        for k, v in tqdm(data, desc=dataset):
            instance = {
                "x1": v["x1"][:],
                "x2": v["x2"][:],
                "cam1": h5_to_camera_dict(v["camera1"]),
                "cam2": h5_to_camera_dict(v["camera2"]),
                "R": v["R"][:],
                "t": v["t"][:],
                "threshold": threshold,
                "opt": opt,
            }

            for name, fcn in evaluators.items():
                errs, runtime = fcn(instance)
                results[name]["errs"].append(np.array(errs))
                results[name]["runtime"].append(runtime)
        metrics[dataset] = compute_metrics(results)
        full_results[dataset] = results
    return metrics, full_results


if __name__ == "__main__":
    force_opt, method_filter, dataset_filter = posebench.parse_args()
    metrics, _ = main(
        force_opt=force_opt, method_filter=method_filter, dataset_filter=dataset_filter
    )
    posebench.print_metrics_per_dataset(metrics)
