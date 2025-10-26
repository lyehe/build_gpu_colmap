# posebench

This repository was setup as a form of regression testing for [PoseLib](https://github.com/vlarsson/PoseLib). Each estimator is compared to the corresponding one in [pycolmap](https://github.com/colmap/pycolmap) if available.

The full benchmark suite can be run as ```python posebench.py``` which will show the average metrics across all datasets. 

Running each individual ```python (absolute_pose|relative_pose|homography).py``` will show the per-dataset statistics.

You can also specify RANSAC options and which specific methods/datasets to run as command line options.
```
usage: posebench.py [-h] [--min_iterations MIN_ITERATIONS] [--max_iterations MAX_ITERATIONS] [--success_prob SUCCESS_PROB]
                    [--method METHOD] [--dataset DATASET]

optional arguments:
  -h, --help            show this help message and exit
  --min_iterations MIN_ITERATIONS
  --max_iterations MAX_ITERATIONS
  --success_prob SUCCESS_PROB
  --method METHOD
  --dataset DATASET
```

## Datasets

The benchmarking is done on a collection of datasets from various papers. Note that we use the same metrics for all datasets in each problem category (and not necessarily the ones used in the original dataset).

The required datasets can be downloaded by running 

```
sh download_data.sh
```

in the root folder.

## TODO

* Add missing estimators (multi-camera, hybrid, etc.)
* Add refinement benchmark
