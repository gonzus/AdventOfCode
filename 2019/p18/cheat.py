#!/usr/bin/env python3

import heapq


def parse_grid(lines):
  grid = {}
  keys = {}
  start = None

  for y, row in enumerate(lines):
    for x, cell in enumerate(row):
      grid[(x, y)] = cell

      if cell == "@":
        start = (x, y)
      elif cell >= "a" and cell <= "z":
        keys[(x, y)] = cell

  return grid, keys, start


def render_grid(grid):
  min_x = min(x for x, _ in grid.keys())
  min_y = min(y for _, y in grid.keys())
  max_x = max(x for x, _ in grid.keys())
  max_y = max(y for _, y in grid.keys())

  grid_str = "\n".join(("".join(grid[(x, y)] for x in range(min_x, max_x + 1))) for y in range(min_y, max_y + 1))
  print(f"{grid_str}\n")


def alter_grid(grid, start):
  grid[start] = "#"
  for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
    pt = (start[0] + dx, start[1] + dy)
    grid[pt] = "#"

  starts = []
  for dx, dy in ((1, -1), (1, 1), (-1, 1), (-1, -1)):
    pt = (start[0] + dx, start[1] + dy)
    starts.append(pt)
    grid[pt] = "@"

  return starts


def shortest_path(grid, src, tgt):
  path_steps = None
  doors = set()
  visited = set()

  q = [(0, src, set())]

  while len(q):
    steps, pos, doors = heapq.heappop(q)
    visited.add(pos)

    if pos == tgt:
      path_steps = steps
      break

    if grid[pos] >= "A" and grid[pos] <= "Z":
      doors = doors.copy()
      doors.add(grid[pos].lower())

    for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
      nx, ny = pos[0] + dx, pos[1] + dy
      if (nx, ny) in visited:
        continue
      if grid.get((nx, ny), "#") == "#":
        continue
      heapq.heappush(q, (steps + 1, (nx, ny), doors))

  return path_steps, doors


def find_key_paths(grid, keys, starts):
  keypaths = {k: {} for k in keys.values()}

  for start_pos, start in enumerate(starts):
    start_label = "@" + str(start_pos)
    keypaths[start_label] = {}

    for src_pos, src in keys.items():
      steps, doors = shortest_path(grid, start, src_pos)
      if steps is not None:
        keypaths[start_label][src] = {"pos": src_pos, "steps": steps, "doors": doors}

      for tgt_pos, tgt in keys.items():
        if tgt == src:
            continue
        if src in keypaths[tgt]:
            continue

        steps, doors = shortest_path(grid, src_pos, tgt_pos)
        if steps is not None:
          keypaths[src][tgt] = {"pos": tgt_pos, "steps": steps, "doors": doors}
          keypaths[tgt][src] = {"pos": src_pos, "steps": steps, "doors": doors}

  return keypaths


def find_keys(grid, keypaths, pos_map, found, bot_id, key, cache={}):
  if len(found) == len(keypaths):
    return 0

  bot_prev = pos_map[bot_id]
  pos_map[bot_id] = key
  # len(pos_map) is always 1 for part 1, 4 for part 2
  # print(f"{len(pos_map)}");

  cachekey = "".join(sorted(pos_map.values())) + "".join(sorted(set(keypaths.keys()) - found))
  if cachekey not in cache:
    min_steps = 99999999999

    for iter_bot_id, iter_bot_key in pos_map.items():
      for iter_key in keypaths[iter_bot_id]:
        if iter_key in found:
          continue
        path = keypaths[iter_bot_key][iter_key]
        if path["doors"] - found != set():
          continue

        steps = find_keys(grid, keypaths, pos_map, found | {iter_key}, iter_bot_id, iter_key, cache)
        new_steps = path["steps"] + steps
        if min_steps <= new_steps:
          continue;
        min_steps = new_steps

    cache[cachekey] = min_steps

  pos_map[bot_id] = bot_prev
  return cache[cachekey]


def run():
  with open('../data/input18.txt', 'r') as input:
    lines = input.read().strip()

  grid, keys, start = parse_grid(lines.split("\n"))
  # render_grid(grid)

  parts = {1: 4228, 2: 1858}
  for part, expected in parts.items():
    if part == 1:
        starts = [start]
        pos_map = {"@0": "@0"}
    else:
        print()
        starts = alter_grid(grid, start)
        pos_map = {"@" + str(i): "@" + str(i) for i in range(0, len(starts))}

    keypaths = find_key_paths(grid, keys, starts)
    found = set(x for x in keypaths.keys() if x[0] == "@")
    steps = find_keys(grid, keypaths, pos_map, found, "@0", "@0")
    print(f"PART {part} {"OK" if steps == expected else "BAD"}")
    print(f"All keys found in {steps} steps")

if __name__ == '__main__':
  run()
