"""Corrigé du TP 1 : taquin 3x3 par recherche en largeur."""
from collections import deque

BUT = (1, 2, 3, 4, 5, 6, 7, 8, 0)


def voisins(etat):
    i = etat.index(0)
    ligne, col = divmod(i, 3)
    for dl, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
        l, c = ligne + dl, col + dc
        if 0 <= l < 3 and 0 <= c < 3:
            j = 3 * l + c
            s = list(etat)
            s[i], s[j] = s[j], s[i]
            yield tuple(s)


def largeur(depart):
    parents = {depart: None}
    file = deque([depart])
    while file:
        etat = file.popleft()
        if etat == BUT:
            chemin = []
            while etat is not None:
                chemin.append(etat)
                etat = parents[etat]
            return chemin[::-1]
        for v in voisins(etat):
            if v not in parents:
                parents[v] = etat
                file.append(v)
    return None


if __name__ == "__main__":
    chemin = largeur((1, 2, 3, 4, 0, 6, 7, 5, 8))
    print(f"{len(chemin) - 1} coups")
