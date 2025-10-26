from posebench import run_benchmark


def test_benchmark():
    run_benchmark(
        subset=True,
        subsample=10,
    )
