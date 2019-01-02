use std::io::{self, BufRead};

const GRID_SIZE:usize = 300;
// const GRID_SIZE:usize = 10;

#[derive(Debug)]
struct Info {
    serial: i32,
    power: i32,
    x: usize,
    y: usize,
}
impl Info {
    pub fn new(serial: i32, power: i32, x: usize, y: usize) -> Info {
        Info{ serial, power, x, y }
    }
}

// 235,65,10 BAD
// 229,61,16 GOOD
fn main() {
    let infos = read_lines();
    for info in infos {
        search(&info);
    }
}

fn read_lines() -> Vec<Info> {
    let mut infos = Vec::new();
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let words: Vec<&str> = line.split_whitespace().collect();
        let serial = words[0].to_string().parse::<i32>().unwrap();
        let power = if words.len() > 1 { words[1].to_string().parse::<i32>().unwrap() } else { 0 };
        let x = if words.len() > 2 { words[2].to_string().parse::<usize>().unwrap() } else { 0 };
        let y = if words.len() > 3 { words[3].to_string().parse::<usize>().unwrap() } else { 0 };
        let info = Info::new(serial, power, x, y);
        infos.push(info);
    }
    infos
}

struct Grid {
    serial: i32,
    grid_size: usize,
    power: Vec<i32>,
}
impl Grid {
    pub fn new(serial: i32, grid_size: usize) -> Grid {
        let size = grid_size * grid_size;
        let mut grid = Grid{ serial, grid_size, power: vec![0; size] };
        for x in 0..grid_size {
            for y in 0..grid_size {
                let pos = x * grid_size + y;
                grid.power[pos] = grid.cell_power(x, y);
                // println!("{} {} => {}", x+1, y+1, grid.power[pos]);
            }
        }
        grid
    }
    pub fn print(&self) {
        for y in 0..self.grid_size {
            for x in 0..self.grid_size {
                let pos = x * self.grid_size + y;
                print!("{:#3}", self.power[pos]);
            }
            println!("");
        }
    }
    fn cell_power(&self, x: usize, y: usize) -> i32 {
        let x = x as i32 + 1;
        let y = y as i32 + 1;
        let rack_id: i32 = x + 10;
        let mut power: i32 = rack_id * y;
        power += self.serial;
        power *= rack_id;
        power = (power % 1000) / 100;
        power -= 5;
        power
    }
}

fn search(info: &Info) {
    println!("info {:?}", info);
    let grid = Grid::new(info.serial, GRID_SIZE);
    let mut top_x: i32 = -1;
    let mut top_y: i32 = -1;
    let mut top_s: i32 = -1;
    let mut top_p: i32 = -1;
    let mut tot: Vec<i32> = vec![0; GRID_SIZE];
    for s in 1..GRID_SIZE+1 {
        println!("size {}", s);
        // grid.print();
        for y in 0..GRID_SIZE {
            let mut tot_y: i32 = 0;
            for x in 0..GRID_SIZE {
                // println!(": {} {} {}", s, y, x);
                tot[x] = 0;
                let mut ok = true;
                for dy in 0..s {
                    let ty = y + dy;
                    if ty >= GRID_SIZE {
                        ok = false;
                        break;
                    }
                    tot[x] += grid.cell_power(x, ty);
                }
                if !ok {
                    continue;
                }
                // println!("+ tot[{}] = {}", x, tot[x]);
                tot_y += tot[x];
                if x >= s {
                    tot_y -= tot[x - s];
                    // println!("- tot[{}] = {}", x-s, tot[x-s]);
                }
                // println!("= tot = {}", tot_y);
                if x < s-1 {
                    continue;
                }

                // println!("C tot = {}", tot_y);
                if top_p < tot_y {
                    top_p = tot_y;
                    top_s = s as i32;
                    top_x = (x - (s - 1)) as i32;
                    top_y = y as i32;
                }
            }
        }
    }
    println!("top {},{},{} => {}", top_x+1, top_y+1, top_s, top_p);
}
