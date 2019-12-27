extern crate regex;

use std::env;
use std::io::{self, BufRead};
use std::collections::HashMap;
use regex::Regex;

fn main() {
    let args: Vec<String> = env::args().collect();
    let top = if args.len() > 1 { args[1].parse::<i32>().unwrap() } else { 10_000 };
    let lines = read_lines();
    process_lines(&lines, top);
}

fn read_lines() -> Vec<String> {
    let mut lines = Vec::new();
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        lines.push(line.unwrap());
    }
    lines
}

fn process_lines(lines: &Vec<String>, top: i32) {
    let re = Regex::new(
        r#"(?x)
          ^
          \s*
          (?P<x>\d+)  # x coordinate
          \s*
          [,]
          \s*
          (?P<y>\d+)  # y coordinate
          \s*
          $
          "#).unwrap();

    let mut points = Vec::new();
    let mut pmin = Point::new_min();
    let mut pmax = Point::new_max();
    for line in lines {
        let caps = re.captures(&line).unwrap();
        let x = get_capture_as_i32(&caps, "x".to_string());
        let y = get_capture_as_i32(&caps, "y".to_string());

        let point = Point::new(x, y);
        // println!("{}", point);
        points.push(point);
        if pmin.x > x {
            pmin.x = x;
        }
        if pmax.x < x {
            pmax.x = x;
        }
        if pmin.y > y {
            pmin.y = y;
        }
        if pmax.y < y {
            pmax.y = y;
        }
    }
    println!("CNT {} points, MIN {}, MAX {}", points.len(), pmin, pmax);

    find_farthest(&points, &pmin, &pmax);
    find_closest(&points, &pmin, &pmax, top);
}

fn find_farthest(points: &Vec<Point>, pmin: &Point, pmax: &Point) {
    let grid = Grid::new(&pmin, &pmax);
    println!("GRID {}", grid);

    let mut top = HashMap::new();
    let mut tainted = HashMap::new();
    for x in grid.pmin.x..grid.pmax.x {
        for y in grid.pmin.y..grid.pmax.y {
            let coord = Point::new(x, y);
            let mut min_dist = std::i32::MAX;
            let mut min_count = 0;
            let mut pmin = Point::new_min();
            for point in points {
                let dist = grid.manhattan(&coord, point);
                // println!("{} - {} = {}", coord, point, dist);
                if dist == 0 {
                    break;
                }
                if min_dist < dist {
                    continue;
                }
                if min_dist == dist {
                    min_count += 1;
                    continue;
                }
                pmin = *point;
                min_dist = dist;
                min_count = 1;
            }
            // println!("{} => {} {} ({})", coord, pmin, min_dist, min_count);
            if min_count > 1 {
                continue;
            }
            if grid.in_border(&coord) {
                // found pmin for a border point, so mark it as tainted
                tainted.insert(Point::new(pmin.x, pmin.y), 1);
            }
            let mut sum = top.entry(pmin).or_insert(1);  // 1 for the pos itself
            *sum += 1;
        }
    }
    let mut top_sum = 0;
    let mut ptop = Point::new_max();
    for k in top.keys() {
        if tainted.contains_key(k) {
            // println!("{} => TAINTED", k);
            continue;
        }
        let sum = top.get(k).unwrap();
        // println!("{} => {}", k, sum);
        if top_sum < *sum {
            top_sum = *sum;
            ptop = *k;
        }
    }
    if top_sum == 0 {
        println!("NO ANSWER");
    } else {
        println!("FARTHEST {} => {}", ptop, top_sum);
    }
}

fn find_closest(points: &Vec<Point>, pmin: &Point, pmax: &Point, top: i32) {
    let margin_x = top - pmax.x;
    let margin_y = top - pmax.y;
    let grid = Grid::new_with_margin(&pmin, &pmax, margin_x, margin_y);
    println!("GRID {}, margins {} {}", grid, margin_x, margin_y);
    let mut total_points = 0;
    for x in grid.pmin.x..grid.pmax.x {
        for y in grid.pmin.y..grid.pmax.y {
            let coord = Point::new(x, y);
            let mut total_dist = 0;
            for point in points {
                let dist = grid.manhattan(&coord, point);
                total_dist += dist;
                if total_dist >= top {
                    break;
                }
            }
            if total_dist >= top {
                continue;
            }
            // println!("{} => {}", coord, total_dist);
            total_points += 1;
        }
    }
    println!("CLOSEST {}", total_points);
}

#[derive(Copy, Clone)]
#[derive(Eq, Hash)]
struct Point {
    x: i32,
    y: i32,
}
impl PartialEq for Point {
    fn eq(&self, other: &Point) -> bool {
        self.x == other.x && self.y == other.y
    }
}
impl std::fmt::Display for Point {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "[{}:{}]", self.x, self.y)
    }
}
impl Point {
    pub fn new(x: i32, y: i32) -> Point {
        Point { x, y }
    }
    pub fn new_min() -> Point {
        Point { x: std::i32::MAX, y: std::i32::MAX }
    }
    pub fn new_max() -> Point {
        Point { x: std::i32::MIN, y: std::i32::MIN }
    }
}

struct Grid {
    pmin: Point,
    pmax: Point,
}
impl std::fmt::Display for Grid {
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        write!(f, "{} - {}", self.pmin, self.pmax)
    }
}
impl Grid {
    pub fn new(pmin: &Point, pmax: &Point) -> Grid {
        Grid::new_with_margin(pmin, pmax, 0, 0)
    }
    pub fn new_with_margin(pmin: &Point, pmax: &Point, margin_x: i32, margin_y: i32) -> Grid {
        let pmin = Point { x: pmin.x - margin_x    , y: pmin.y - margin_y     };
        let pmax = Point { x: pmax.x + margin_x + 1, y: pmax.y + margin_y + 1 };
        Grid { pmin, pmax }
    }
    pub fn manhattan(&self, p0: &Point, p1: &Point) -> i32 {
        let dx = (p0.x - p1.x).abs();
        let dy = (p0.y - p1.y).abs();
        dx + dy
    }
    pub fn in_border(&self, p: &Point) -> bool {
        p.x   == self.pmin.x || p.y   == self.pmin.y ||
        p.x+1 == self.pmax.x || p.y+1 == self.pmax.y
    }
}

fn get_capture_as_i32(caps: &regex::Captures, name: String) -> i32 {
    match caps.name(&name) {
        Some(cap) => cap.as_str().parse::<i32>().unwrap(),
        None => -1,
    }
}
