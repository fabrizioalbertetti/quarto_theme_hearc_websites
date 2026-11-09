"""Fonctions utilitaires du TP 1 (régression linéaire)."""
import numpy as np
import matplotlib.pyplot as plt


def charger_donnees(n=50, seed=0):
    """Données synthétiques : température (°C) -> consommation (kWh)."""
    rng = np.random.default_rng(seed)
    temperature = rng.uniform(-5, 25, n)
    consommation = 40 - 1.2 * temperature + rng.normal(0, 3, n)
    X = np.column_stack([np.ones(n), temperature])
    return X, consommation


def tracer(X, y, w):
    """Nuage de points et droite de régression."""
    plt.scatter(X[:, 1], y, label="mesures")
    t = np.linspace(X[:, 1].min(), X[:, 1].max(), 100)
    plt.plot(t, w[0] + w[1] * t, color="red", label="régression")
    plt.xlabel("température (°C)")
    plt.ylabel("consommation (kWh)")
    plt.legend()
    plt.show()
