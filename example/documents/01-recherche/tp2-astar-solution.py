"""Corrigé du TP 2 : A* sur une grille (0 = libre, 1 = obstacle)."""
import heapq


def manhattan(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def astar(grille, depart, arrivee, h=manhattan):
    ouverts = [(h(depart, arrivee), 0, depart)]
    cout = {depart: 0}
    parent = {depart: None}
    while ouverts:
        _, g, n = heapq.heappop(ouverts)
        if n == arrivee:
            chemin = []
            while n is not None:
                chemin.append(n)
                n = parent[n]
            return chemin[::-1]
        l, c = n
        for v in ((l + 1, c), (l - 1, c), (l, c + 1), (l, c - 1)):
            if 0 <= v[0] < len(grille) and 0 <= v[1] < len(grille[0]) and not grille[v[0]][v[1]]:
                if g + 1 < cout.get(v, float("inf")):
                    cout[v] = g + 1
                    parent[v] = n
                    heapq.heappush(ouverts, (g + 1 + h(v, arrivee), g + 1, v))
    return None
