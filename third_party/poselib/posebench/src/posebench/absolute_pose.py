import datetime

import h5py
import numpy as np
import poselib
import pycolmap
from tqdm import tqdm

import posebench
from posebench.utils.geometry import eigen_quat_to_wxyz, qvec2rotmat, rotation_angle
from posebench.utils.misc import (
    compute_auc,
    h5_to_camera_dict,
    poselib_opt_to_pycolmap_opt,
    substr_in_list,
)


# Compute metrics for absolute pose estimation
# AUC for camera center and avg/med for runtime
def compute_metrics(results, thresholds=[0.1, 1.0, 5.0]):
    methods = results.keys()
    metrics = {}
    for m in methods:
        rot_err = [a for (a, b) in results[m]["errs"]]
        cc_err = [b for (a, b) in results[m]["errs"]]
        metrics[m] = {}
        aucs = compute_auc(cc_err, thresholds)
        for auc, t in zip(aucs, thresholds):
            metrics[m][f"AUC{int(t)}"] = auc
        metrics[m]["med_rot"] = np.median(rot_err)
        metrics[m]["med_pos"] = np.median(cc_err)
        metrics[m]["avg_rt"] = np.mean(results[m]["runtime"])
        metrics[m]["med_rt"] = np.median(results[m]["runtime"])

    return metrics


def eval_pnp_estimator(instance, estimator="poselib_pnp"):
    opt = instance["opt"]

    if estimator == "poselib_pnp":
        tt1 = datetime.datetime.now()
        pose, info = poselib.estimate_absolute_pose(
            instance["p2d"], instance["p3d"], instance["cam"], opt, {}
        )
        tt2 = datetime.datetime.now()
        (R, t) = (pose.R, pose.t)
    elif estimator == "poselib_pnpl":
        tt1 = datetime.datetime.now()
        pose, info = poselib.estimate_absolute_pose_pnpl(
            instance["p2d"],
            instance["p3d"],
            instance["l2d"][:, 0:2],
            instance["l2d"][:, 2:4],
            instance["l3d"][:, 0:3],
            instance["l3d"][:, 3:6],
            instance["cam"],
            opt,
            {},
        )
        tt2 = datetime.datetime.now()
        (R, t) = (pose.R, pose.t)
    elif estimator == "pycolmap":
        opt = poselib_opt_to_pycolmap_opt(opt)
        tt1 = datetime.datetime.now()
        result = pycolmap.estimate_and_refine_absolute_pose(
            instance["p2d"],
            instance["p3d"],
            instance["cam"],
            {"estimate_focal_length": False, "ransac": opt},
        )
        tt2 = datetime.datetime.now()
        R = qvec2rotmat(eigen_quat_to_wxyz(result["cam_from_world"].rotation.quat))
        t = result["cam_from_world"].translation

    err_R = rotation_angle(instance["R"] @ R.T)
    err_c = np.linalg.norm(instance["R"].T @ instance["t"] - R.T @ t)
    return [err_R, err_c], (tt2 - tt1).total_seconds()


def main(
    dataset_path="data/absolute",
    force_opt={},
    dataset_filter=[],
    method_filter=[],
    subsample=None,
):
    datasets = [
        ("eth3d_130_dusmanu", 12.0),
        ("7scenes_heads", 5.0),
        ("7scenes_stairs", 5.0),
        ("cambridge_landmarks_GreatCourt", 6.0),
        ("cambridge_landmarks_ShopFacade", 6.0),
        ("cambridge_landmarks_KingsCollege", 6.0),
        ("cambridge_landmarks_StMarysChurch", 6.0),
        ("cambridge_landmarks_OldHospital", 6.0),
    ]

    if len(dataset_filter) > 0:
        datasets = [(n, t) for (n, t) in datasets if substr_in_list(n, dataset_filter)]

    evaluators = {
        "PnP (poselib)": lambda i: eval_pnp_estimator(i, estimator="poselib_pnp"),
        "PnP (COLMAP)": lambda i: eval_pnp_estimator(i, estimator="pycolmap"),
        #'PnPL (poselib)': lambda i: eval_pnp_estimator(i, estimator='poselib_pnpl')
    }

    if len(method_filter) > 0:
        evaluators = {
            k: v for (k, v) in evaluators.items() if substr_in_list(k, method_filter)
        }

    metrics = {}
    full_results = {}
    for dataset, threshold in datasets:
        f = h5py.File(f"{dataset_path}/{dataset}.h5", "r")

        results = {}
        for k in evaluators.keys():
            results[k] = {"errs": [], "runtime": []}

        # RANSAC options
        opt = {
            "max_reproj_error": threshold,
            "max_epipolar_error": threshold,
            "max_iterations": 1000,
            "min_iterations": 100,
            "success_prob": 0.9999,
        }

        # Add in global overrides
        for k, v in force_opt.items():
            opt[k] = v

        data = list(f.items())
        if subsample is not None:
            print(
                f"Subsampling {len(data)} instances to {len(data) // subsample} instances"
            )
            data = data[::subsample]

        for k, v in tqdm(data, desc=dataset, total=len(data)):
            instance = {
                "p2d": v["p2d"][:],
                "p3d": v["p3d"][:],
                "cam": h5_to_camera_dict(v["camera"]),
                "R": v["R"][:],
                "t": v["t"][:],
                "threshold": threshold,
                "opt": opt,
            }

            # Check if we have 2D-3D line correspondences
            if "l2d" in v:
                instance["l2d"] = v["l2d"][:]
                instance["l3d"] = v["l3d"][:]
            else:
                instance["l2d"] = np.zeros((0, 4))
                instance["l3d"] = np.zeros((0, 6))

            # Run each of the evaluators
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
