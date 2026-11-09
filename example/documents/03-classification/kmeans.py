"""k-means minimal, sans scikit-learn."""
import numpy as np


def kmeans(X, k, iterations=100, seed=0):
    rng = np.random.default_rng(seed)
    centres = X[rng.choice(len(X), k, replace=False)]
    for _ in range(iterations):
        # affectation de chaque point au centre le plus proche
        labels = np.argmin(((X[:, None] - centres) ** 2).sum(axis=2), axis=1)
        nouveaux = np.array([X[labels == j].mean(axis=0) for j in range(k)])
        if np.allclose(nouveaux, centres):
            break
        centres = nouveaux
    return centres, labels


if __name__ == "__main__":
    rng = np.random.default_rng(1)
    X = np.vstack([rng.normal(c, 0.5, (30, 2)) for c in ((0, 0), (3, 3), (0, 4))])
    centres, labels = kmeans(X, 3)
    print(centres)
