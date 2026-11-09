"""Corrigé du TP 1 : régression linéaire par moindres carrés."""
import numpy as np
from utils import charger_donnees, tracer

X, y = charger_donnees()

# Équations normales : w = (X^T X)^-1 X^T y
w = np.linalg.solve(X.T @ X, X.T @ y)
print(f"ordonnée à l'origine : {w[0]:.2f}, pente : {w[1]:.2f}")

tracer(X, y, w)
