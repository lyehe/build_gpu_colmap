import numpy as np
import pycolmap
import requests
from tqdm import tqdm


def trapezoid(y, x=None, dx=1.0, axis=-1):
    if np.__version__ < "2.0.0":
        return np.trapz(y, x=x, dx=dx, axis=axis)
    else:
        return np.trapezoid(y, x=x, dx=dx, axis=axis)


def substr_in_list(s, lst):
    return np.any([s.find(t) >= 0 for t in lst])


def poselib_opt_to_pycolmap_opt(opt):
    pyc_opt = pycolmap.RANSACOptions()

    if "max_reproj_error" in opt:
        pyc_opt.max_error = opt["max_reproj_error"]
    elif "max_epipolar_error" in opt:
        pyc_opt.max_error = opt["max_epipolar_error"]

    if "max_iterations" in opt:
        pyc_opt.max_num_trials = opt["max_iterations"]
    if "min_iterations" in opt:
        pyc_opt.min_num_trials = opt["min_iterations"]

    if "success_prob" in opt:
        pyc_opt.confidence = opt["success_prob"]

    return pyc_opt


def h5_to_camera_dict(data):
    camera_dict = {}
    camera_dict["model"] = data["model"].asstr()[0]
    camera_dict["width"] = int(data["width"][0])
    camera_dict["height"] = int(data["height"][0])
    camera_dict["params"] = data["params"][:]
    return camera_dict


def calib_matrix_to_camera_dict(K):
    camera_dict = {}
    camera_dict["model"] = "PINHOLE"
    camera_dict["width"] = int(np.ceil(K[0, 2] * 2))
    camera_dict["height"] = int(np.ceil(K[1, 2] * 2))
    camera_dict["params"] = [K[0, 0], K[1, 1], K[0, 2], K[1, 2]]
    return camera_dict


def camera_dict_to_calib_matrix(cam):
    if cam["model"] == "PINHOLE":
        p = cam["params"]
        return np.array([[p[0], 0.0, p[2]], [0.0, p[1], p[3]], [0.0, 0.0, 1.0]])
    else:
        raise Exception("nyi model in camera_dict_to_calib_matrix")


# From Paul
def compute_auc(errors, thresholds):
    sort_idx = np.argsort(errors)
    errors = np.array(errors.copy())[sort_idx]
    recall = (np.arange(len(errors)) + 1) / len(errors)
    errors = np.r_[0.0, errors]
    recall = np.r_[0.0, recall]
    aucs = []
    for t in thresholds:
        last_index = np.searchsorted(errors, t)
        r = np.r_[recall[:last_index], recall[last_index - 1]]
        e = np.r_[errors[:last_index], t]
        aucs.append(trapezoid(r, x=e) / t)
    return aucs


def format_metric(name, value):
    name = name.upper()
    if "AUC" in name:
        return f"{100.0 * value:>6.2f}"
    elif "ROT" in name:
        return f"{value:-3.1E}"
    elif "INL" in name:
        return f"{value:-3.5f}"
    elif "RMS" in name:
        return f"{value:-3.4f}px"
    elif "MSAC" in name:
        return f"{value:-3.4f}px"
    elif "POS" in name:
        return f"{value:-3.1f}"
    elif "TIME" in name or "RT" in name:
        if value < 1e-6:
            return f"{1e9 * value:-5.1f}ns"
        elif value < 1e-3:
            return f"{1e6 * value:-5.1f}us"
        elif value < 1.0:
            return f"{1e3 * value:-5.1f}ms"
        else:
            return f"{value:.2}s"
    else:
        return f"{value}"


def print_metrics_per_method(metrics):
    for name, res in metrics.items():
        s = f"{name:18s}: "
        for metric_name, value in res.items():
            s = s + f"{metric_name}={format_metric(metric_name, value)}" + ", "
        s = s[0:-2]
        print(s)


def print_metrics_per_method_table(metrics, sort_by_metric=None, reverse_sort=False):
    method_names = list(metrics.keys())
    if len(method_names) == 0:
        return
    metric_names = list(metrics[method_names[0]].keys())

    if sort_by_metric is not None:
        vals = [metrics[m][sort_by_metric] for m in method_names]
        if reverse_sort:
            ind = np.argsort(-np.array(vals))
        else:
            ind = np.argsort(np.array(vals))
        method_names = np.array(method_names)[ind]

    field_lengths = {x: len(x) + 2 for x in metric_names}
    name_length = np.max([len(x) for x in metrics.keys()])

    # print header
    print(f"{'':{name_length}s}", end=" ")
    for metric_name in metric_names:
        print(f"{metric_name:>{field_lengths[metric_name]}s}", end=" ")
    print("")

    for name in method_names:
        res = metrics[name]
        print(f"{name:{name_length}s}", end=" ")
        for metric_name, value in res.items():
            print(
                f"{format_metric(metric_name, value):>{field_lengths[metric_name]}s}",
                end=" ",
            )
        print("")


def print_metrics_per_dataset(
    metrics, as_table=True, sort_by_metric=None, reverse_sort=False
):
    for dataset in metrics.keys():
        print(f"Dataset: {dataset}")
        if as_table:
            print_metrics_per_method_table(
                metrics[dataset],
                sort_by_metric=sort_by_metric,
                reverse_sort=reverse_sort,
            )
        else:
            print_metrics_per_method(metrics[dataset])


def compute_average_metrics(metrics):
    avg_metrics = {}
    for dataset, dataset_metrics in metrics.items():
        for method, res in dataset_metrics.items():
            if method not in avg_metrics:
                avg_metrics[method] = {}

            for m_name, m_val in res.items():
                if m_name not in avg_metrics[method]:
                    avg_metrics[method][m_name] = []
                avg_metrics[method][m_name].append(m_val)

    for method in avg_metrics.keys():
        for m_name, m_vals in avg_metrics[method].items():
            avg_metrics[method][m_name] = np.mean(m_vals)

    return avg_metrics


def download_file_with_progress(url, filename):
    response = requests.get(url, stream=True)
    response.raise_for_status()

    total_size = int(response.headers.get("content-length", 0))

    with open(filename, "wb") as file, tqdm(
        desc=f"Downloading {filename}",
        total=total_size,
        unit="B",
        unit_scale=True,
        unit_divisor=1024,
    ) as progress_bar:
        for chunk in response.iter_content(chunk_size=8192):
            if chunk:
                file.write(chunk)
                progress_bar.update(len(chunk))
