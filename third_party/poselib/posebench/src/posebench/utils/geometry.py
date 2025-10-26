import numpy as np
import math


def calibrate_pts(pts, K):
    pts_calib = pts.copy()
    pts_calib[:, 0] -= K[0, 2]
    pts_calib[:, 1] -= K[1, 2]
    pts_calib[:, 0] /= K[0, 0]
    pts_calib[:, 1] /= K[1, 1]
    return pts_calib


def rotation_angle(R):
    return np.rad2deg(np.arccos(np.clip((np.trace(R) - 1) / 2, -1, 1)))


def angle(v1, v2):
    v1s = np.squeeze(v1)
    v2s = np.squeeze(v2)
    # if np.linalg.norm(v1) == 0:
    #     raise RuntimeError
    n = np.linalg.norm(v1s) * np.linalg.norm(v2s)
    return np.rad2deg(np.arccos(np.clip(np.dot(v1s, v2s) / n, -1.0, 1.0)))


def eigen_quat_to_wxyz(quat):
    return np.array([quat[3], quat[0], quat[1], quat[2]])


def qvec2rotmat(qvec):
    return np.array(
        [
            [
                1 - 2 * qvec[2] ** 2 - 2 * qvec[3] ** 2,
                2 * qvec[1] * qvec[2] - 2 * qvec[0] * qvec[3],
                2 * qvec[3] * qvec[1] + 2 * qvec[0] * qvec[2],
            ],
            [
                2 * qvec[1] * qvec[2] + 2 * qvec[0] * qvec[3],
                1 - 2 * qvec[1] ** 2 - 2 * qvec[3] ** 2,
                2 * qvec[2] * qvec[3] - 2 * qvec[0] * qvec[1],
            ],
            [
                2 * qvec[3] * qvec[1] - 2 * qvec[0] * qvec[2],
                2 * qvec[2] * qvec[3] + 2 * qvec[0] * qvec[1],
                1 - 2 * qvec[1] ** 2 - 2 * qvec[2] ** 2,
            ],
        ]
    )


def essential_from_pose(R, t):
    t = t.flatten()
    return np.array([[0, -t[2], t[1]], [t[2], 0, -t[0]], [-t[1], t[0], 0]]) @ R


def skew(t):
    t = t.flatten()
    return np.array([[0, -t[2], t[1]], [t[2], 0, -t[0]], [-t[1], t[0], 0]])


def sampson_error(F, x1, x2):
    num_pts = x1.shape[0]
    x1h = np.c_[x1, np.ones(num_pts)]
    x2h = np.c_[x2, np.ones(num_pts)]
    Fx1 = F @ x1h.transpose()
    Fx2 = F.transpose() @ x2h.transpose()

    C = np.sum(x2h.transpose() * Fx1, axis=0)
    denom = Fx1[0, :] ** 2 + Fx1[1, :] ** 2 + Fx2[0, :] ** 2 + Fx2[1, :] ** 2

    samp_err = np.abs(C) / np.sqrt(denom)
    return samp_err


def sym_epipolar_error(F, x1, x2):
    num_pts = x1.shape[0]
    x1h = np.c_[x1, np.ones(num_pts)]
    x2h = np.c_[x2, np.ones(num_pts)]
    Fx1 = F @ x1h.transpose()
    Fx2 = F.transpose() @ x2h.transpose()

    C = np.sum(x2h.transpose() * Fx1, axis=0)
    denom1 = np.sqrt(Fx1[0, :] ** 2 + Fx1[1, :] ** 2)
    denom2 = np.sqrt(Fx2[0, :] ** 2 + Fx2[1, :] ** 2)

    sym_err = np.abs(C) * (1 / denom1 + 1 / denom2)
    return sym_err


def check_cheirality(R, t, x1, x2, K1, K2):
    num_pts = x1.shape[0]
    x1h = np.c_[x1, np.ones(num_pts)]
    x2h = np.c_[x2, np.ones(num_pts)]

    x1h = np.linalg.inv(K1) @ x1h.transpose()
    x2h = np.linalg.inv(K2) @ x2h.transpose()

    cheiral_ok = []
    for i in range(num_pts):
        z1 = x1h[:, i]
        z2 = x2h[:, i]

        S1 = np.array([[0, -z1[2], z1[1]], [z1[2], 0, -z1[0]], [-z1[1], z1[0], 0]])
        S2 = np.array([[0, -z2[2], z2[1]], [z2[2], 0, -z2[0]], [-z2[1], z2[0], 0]])

        A = np.r_[np.c_[S1, np.zeros(3)], S2 @ np.c_[R, t]]

        U, S, Vh = np.linalg.svd(A, full_matrices=True)
        X = Vh[-1, 0:3].transpose() / Vh[-1, 3]

        cheiral_ok.append(X[2] > 0 and R[2, :] @ X + t[2] > 0)

    return cheiral_ok


def triangulate(R, t, x1, x2):
    num_pts = x1.shape[0]
    x1h = np.c_[x1, np.ones(num_pts)]
    x2h = np.c_[x2, np.ones(num_pts)]
    X = []
    for i in range(num_pts):
        z1 = x1h[i, :]
        z2 = x2h[i, :]

        S1 = np.array([[0, -z1[2], z1[1]], [z1[2], 0, -z1[0]], [-z1[1], z1[0], 0]])
        S2 = np.array([[0, -z2[2], z2[1]], [z2[2], 0, -z2[0]], [-z2[1], z2[0], 0]])

        A = np.r_[np.c_[S1, np.zeros(3)], S2 @ np.c_[R, t]]

        U, S, Vh = np.linalg.svd(A, full_matrices=True)
        X.append(Vh[-1, 0:3].transpose() / Vh[-1, 3])

    return np.array(X)


# Code from Daniel
# https://github.com/danini/homography-benchmark/blob/main/errors.py
def decompose_homography(homography):
    u, s, vt = np.linalg.svd(homography)

    H2 = homography / s[1]

    U2, S2, Vt2 = np.linalg.svd(H2.T @ H2)
    V2 = Vt2.T

    if np.linalg.det(V2) < 0:
        V2 *= -1

    s1 = S2[0]
    s3 = S2[2]

    v1 = V2[:, 0]
    v2 = V2[:, 1]
    v3 = V2[:, 2]

    if abs(s1 - s3) < 1e-14:
        return 0, [], [], []

    # compute orthogonal unit vectors
    u1 = (math.sqrt(1.0 - s3) * v1 + math.sqrt(s1 - 1.0) * v3) / math.sqrt(s1 - s3)
    u2 = (math.sqrt(1.0 - s3) * v1 - math.sqrt(s1 - 1.0) * v3) / math.sqrt(s1 - s3)

    U1 = np.zeros((3, 3))
    W1 = np.zeros((3, 3))
    U2 = np.zeros((3, 3))
    W2 = np.zeros((3, 3))

    U1[:, 0] = v2
    U1[:, 1] = u1
    U1[:, 2] = np.cross(v2, u1)

    W1[:, 0] = H2 @ v2
    W1[:, 1] = H2 @ u1
    W1[:, 2] = np.cross(H2 @ v2, H2 @ u1)

    U2[:, 0] = v2
    U2[:, 1] = u2
    U2[:, 2] = np.cross(v2, u2)

    W2[:, 0] = H2 @ v2
    W2[:, 1] = H2 @ u2
    W2[:, 2] = np.cross(H2 @ v2, H2 @ u2)

    # compute the rotation matrices
    R1 = W1 @ U1.T
    R2 = W2 @ U2.T

    # build the solutions, discard those with negative plane normals
    # Compare to the original code, we do not invert the transformation.
    # Furthermore, we multiply t with -1.
    Rs = []
    ts = []
    ns = []

    n = np.cross(v2, u1)
    ns.append(n)
    Rs.append(R1)
    t = -(H2 - R1) @ n
    ts.append(t)

    ns.append(-n)
    t = (H2 - R1) @ n
    Rs.append(R1)
    ts.append(t)

    n = np.cross(v2, u2)
    ns.append(n)
    t = -(H2 - R2) @ n
    Rs.append(R2)
    ts.append(t)

    ns.append(-n)
    t = (H2 - R2) @ n
    ts.append(t)
    Rs.append(R2)

    return 1, Rs, ts, ns
