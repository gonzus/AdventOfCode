use std::io::{self, BufRead};
use std::collections::HashMap;

#[derive(Debug,PartialEq)]
enum Dir {
    North,
    East,
    South,
    West,
}
impl Dir {
    pub fn delta(&self) -> (i32, i32) {
        use Dir::*;
        match *self {
            North => ( 0, -1),
            South => ( 0,  1),
            West  => (-1,  0),
            East  => ( 1,  0),
        }
    }
    pub fn turn_right(&self) -> Dir {
        use Dir::*;
        match *self {
            North => East,
            East  => South,
            South => West,
            West  => North,
        }
    }
    pub fn turn_left(&self) -> Dir {
        use Dir::*;
        match *self {
            North => West,
            West  => South,
            South => East,
            East  => North,
        }
    }
}


#[derive(Debug,PartialEq)]
enum Turn {
    Left,
    Straight,
    Right,
}
impl Turn {
    pub fn next(&self) -> Turn {
        use Turn::*;
        match *self {
            Left     => Straight,
            Straight => Right,
            Right    => Left,
        }
    }
}

#[derive(Debug)]
struct Cart {
    x: i32,
    y: i32,
    dir: Dir,
    turn: Turn,
    active: bool,
}
impl Cart {
    pub fn new(x: i32, y: i32, dir: Dir) -> Cart {
        Cart{ x, y, dir, turn: Turn::Left, active: true }
    }
    pub fn step(&mut self) {
        let (dx, dy) = self.dir.delta();
        self.x += dx;
        self.y += dy;
    }
    pub fn check_turn(&mut self, v: char) {
        let tl = self.dir.turn_left();
        let tr = self.dir.turn_right();
        match v {
            '/'  => {
                self.dir = match self.dir {
                    Dir::North => tr,
                    Dir::South => tr,
                    Dir::East  => tl,
                    Dir::West  => tl,
                };
            },
            '\\' => {
                self.dir = match self.dir {
                    Dir::North => tl,
                    Dir::South => tl,
                    Dir::East  => tr,
                    Dir::West  => tr,
                };
            },
            '+'  => {
                match self.turn {
                    Turn::Left     => self.dir = tl,
                    Turn::Right    => self.dir = tr,
                    Turn::Straight => {},
                };
                self.turn = self.turn.next();
            },
            _    => {},
        };
    }
}

#[derive(Debug)]
struct Board {
    w: usize,
    h: usize,
    data: Vec<char>,
    carts: Vec<Cart>,
}
impl Board {
    pub fn new(lines: &Vec<String>) -> Board {
        let mut h = 0;
        let mut w = 0;
        for line in lines {
            h += 1;
            if w < line.len() {
                w = line.len();
            }
        }
        let size = w * h;
        let data = vec![' '; size];
        let mut board = Board{ w, h, data, carts: Vec::new() };

        let mut y: i32 = 0;
        for line in lines {
            let mut x: i32 = 0;
            for c in line.chars() {
                let mut f = c;
                let dir: Option<Dir> = match c {
                    '^' => { f = '|'; Some(Dir::North) }
                    'v' => { f = '|'; Some(Dir::South) }
                    '<' => { f = '-'; Some(Dir::West)  }
                    '>' => { f = '-'; Some(Dir::East)  }
                    _   => None,
                };
                match dir {
                    Some(d) => {
                        let c = Cart::new(x, y, d);
                        board.carts.push(c);
                    },
                    None => {},
                };
                board.set(x, y, f);
                x += 1;
            }
            y += 1;
        }
        println!("Board {} x {}, {} carts", w, h, board.carts.len());
        board
    }
    pub fn get(&self, x: i32, y: i32) -> char {
        let pos = y * self.w as i32 + x;
        self.data[pos as usize]
    }
    pub fn set(&mut self, x: i32, y: i32, v: char) {
        let pos = y * self.w as i32 + x;
        self.data[pos as usize] = v;
    }
    // pub fn print(&self) {
    //     for y in 0..self.h {
    //         for x in 0..self.w {
    //             print!("{}", self.get(x as i32, y as i32));
    //         }
    //         println!("");
    //     }
    //     for c in &self.carts {
    //         println!("{} {} {:?} {:?}", c.x, c.y, c.dir, c.turn);
    //     }
    // }
    pub fn step(&mut self, repeat: bool) -> bool {
        self.carts.sort_by(|ref a, ref b| if a.y != b.y { a.y.cmp(&b.y) } else { a.x.cmp(&b.x) } );
        let mut seen: HashMap<(i32, i32), usize> = HashMap::new();
        let mut done = false;
        for p in 0..self.carts.len() {
            if !self.carts[p].active {
                continue;
            }
            let (x, y) = (self.carts[p].x, self.carts[p].y);
            if seen.contains_key(&(x, y)) {
                println!("CRASH A {},{}", x, y);
                if repeat {
                    let q = seen.get(&(x, y)).unwrap();
                    self.carts[p].active = false;
                    self.carts[*q].active = false;
                } else {
                    done = true;
                    break;
                }
            }
            seen.insert((x, y), p);
        }
        if done {
            return true;
        }
        if seen.len() == 0 {
            println!("FINAL EMPTY");
            return true;
        } else if seen.len() == 1 {
            for (_, v) in seen {
                println!("FINAL {},{}", self.carts[v].x, self.carts[v].y);
            }
            return true;
        }

        for p in 0..self.carts.len() {
            if !self.carts[p].active {
                continue;
            }
            self.carts[p].step();
            let (x, y) = (self.carts[p].x, self.carts[p].y);
            let v = self.get(x, y);
            self.carts[p].check_turn(v);

            if seen.contains_key(&(x, y)) {
                println!("CRASH B {},{}", x, y);
                if repeat {
                    let q = seen.get(&(x, y)).unwrap();
                    self.carts[p].active = false;
                    self.carts[*q].active = false;
                } else {
                    done = true;
                    break;
                }
            }
        }
        if done {
            return true;
        }
        false
    }
}

fn main() {
    let lines = read_data();
    part(&lines, false);
    println!("=========");
    part(&lines, true);
}

fn part(lines: &Vec<String>, repeat: bool) {
    let mut board = Board::new(&lines);
    let mut ticks = 0;
    loop {
        ticks += 1;
        let done = board.step(repeat);
        if done {
            println!("Part {} done after {} ticks", repeat, ticks);
            break;
        }
    }
}

fn read_data() -> Vec<String> {
    let mut lines = Vec::new();
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        lines.push(line);
    }
    lines
}
