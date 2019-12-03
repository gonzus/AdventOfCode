extern crate regex;

use std::io::{self, BufRead};
use regex::Regex;

#[derive(Debug)]
struct Pair {
    x: i32,
    y: i32,
}
impl Pair {
    pub fn new(x: i32, y: i32) -> Pair {
        Pair{ x, y }
    }
}

#[derive(Debug)]
struct Data {
    pos: Pair,
    vel: Pair,
}
impl Data {
    pub fn new(px: i32, py: i32, vx: i32, vy: i32) -> Data {
        Data{ pos: Pair::new(px, py), vel: Pair::new(vx, vy) }
    }
}

#[derive(Debug)]
struct Grid {
    pos: [Vec<Pair>; 2],
    vel: Vec<Pair>,
    size: [u64; 2],
    cur: usize,
}
impl Grid {
    pub fn new(data: &Vec<Data>) -> Grid {
        let mut p0: Vec<Pair> = Vec::new();
        let mut p1: Vec<Pair> = Vec::new();
        let mut vel: Vec<Pair> = Vec::new();
        for d in data {
            p0.push(Pair::new(d.pos.x, d.pos.y));
            p1.push(Pair::new(d.pos.x, d.pos.y));
            vel.push(Pair::new(d.vel.x, d.vel.y));
        }
        Grid{ pos: [p0, p1], vel: vel, cur: 0, size: [std::u64::MAX, std::u64::MAX] }
    }
    pub fn step(&mut self) {
        let cur = self.cur;
        let nxt = 1 - cur;
        let mut min: Pair = Pair::new(std::i32::MAX, std::i32::MAX);
        let mut max: Pair = Pair::new(std::i32::MIN, std::i32::MIN);
        for j in 0..self.pos[cur].len() {
            let dx = self.pos[cur][j].x;
            let dy = self.pos[cur][j].y;
            let vx = self.vel[j].x;
            let vy = self.vel[j].y;
            let x = dx + vx;
            let y = dy + vy;
            if min.x > x {
                min.x = x;
            }
            if min.y > y {
                min.y = y;
            }
            if max.x < x {
                max.x = x;
            }
            if max.y < y {
                max.y = y;
            }
            self.pos[nxt][j].x = x;
            self.pos[nxt][j].y = y;
        }
        max.x += 1;
        max.y += 1;
        let w = max.y - min.y;
        let h = max.x - min.x;
        self.size[nxt] = (w as u64) * (h as u64);
        self.cur = nxt;
    }
    pub fn done(&mut self) -> bool {
        let cur = self.cur;
        let nxt = 1 - cur;
        let done = self.size[cur] > self.size[nxt];
        if done {
            self.cur = 1 - self.cur;
        }
        done
    }
    pub fn print(&self) {
        let mut min: Pair = Pair::new(std::i32::MAX, std::i32::MAX);
        let mut max: Pair = Pair::new(std::i32::MIN, std::i32::MIN);
        for d in &self.pos[self.cur] {
            if min.x > d.x {
                min.x = d.x;
            }
            if min.y > d.y {
                min.y = d.y;
            }
            if max.x < d.x {
                max.x = d.x;
            }
            if max.y < d.y {
                max.y = d.y;
            }
        }
        max.x += 1;
        max.y += 1;
        let w = max.y - min.y;
        let h = max.x - min.x;
        let size = (w * h) as usize;
        println!("size {} x {} = {}", w, h, size);
        let mut grid = vec![' '; size];
        for d in &self.pos[self.cur] {
            let x = d.x - min.x;
            let y = d.y - min.y;
            let pos = (x * w + y) as usize;
            grid[pos] = '#';
        }
        for y in min.y..max.y {
            let y = y - min.y;
            for x in min.x..max.x {
                let x = x - min.x;
                let pos = (x * w + y) as usize;
                print!("{}", grid[pos]);
            }
            println!("");
        }
    }
}

fn main() {
    let data = read_data();
    let mut grid = Grid::new(&data);
    let mut steps = 0;
    loop {
        if grid.done() {
            break;
        }
        grid.step();
        steps += 1;
    }
    grid.print();
    println!("{} steps, {} seconds", steps, steps - 1);
}

fn read_data() -> Vec<Data> {
    let re = Regex::new(
        r#"(?x)
          ^
          \s*
          position=<
          \s*
          (?P<px>[-0-9]+)
          \s*
          ,
          \s*
          (?P<py>[-0-9]+)
          \s*
          >
          \s*
          velocity=<
          \s*
          (?P<vx>[-0-9]+)
          \s*
          ,
          \s*
          (?P<vy>[-0-9]+)
          \s*
          >
          \s*
          $
          "#).unwrap();
    let mut data = Vec::new();
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let caps = re.captures(&line).unwrap();
        let px = get_capture_as_i32(&caps, "px".to_string());
        let py = get_capture_as_i32(&caps, "py".to_string());
        let vx = get_capture_as_i32(&caps, "vx".to_string());
        let vy = get_capture_as_i32(&caps, "vy".to_string());
        data.push(Data::new(px, py, vx, vy));
    }
    data
}

fn get_capture_as_i32(caps: &regex::Captures, name: String) -> i32 {
    match caps.name(&name) {
        Some(cap) => cap.as_str().parse::<i32>().unwrap(),
        None => 0,
    }
}
