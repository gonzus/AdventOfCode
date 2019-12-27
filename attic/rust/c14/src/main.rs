use std::io::{self, BufRead};
use std::time::Instant;

#[derive(Debug)]
struct Data {
    iters: usize,
    expected: String,
}
impl Data {
    pub fn new(iters: usize, expected: String) -> Data {
        Data{ iters, expected }
    }
}

#[derive(Debug)]
struct Recipe {
    scores: Vec<u8>,
    current: Vec<usize>,
    total: u64,
}
impl Recipe {
    pub fn new(initial: &Vec<u8>) -> Recipe {
        let mut scores: Vec<u8> = Vec::new();
        let mut current: Vec<usize> = Vec::new();
        let mut total: u64 = 0;
        let mut pos = 0;
        for s in initial {
            scores.push(*s);
            current.push(pos);
            total += *s as u64;
            pos += 1;
        }
        Recipe{ scores, current, total }
    }
    pub fn step(&mut self) {
        let mut total = 0;
        for p in 0..self.current.len() {
            let pos = self.current[p];
            total += self.scores[pos] as usize;
        }
        for c in total.to_string().chars() {
            let d = c as u8 - '0' as u8;
            self.scores.push(d);
            self.total += d as u64;
        }
        for p in 0..self.current.len() {
            let mut pos = self.current[p];
            pos = pos + 1 + self.scores[pos] as usize;
            pos %= self.scores.len();
            self.current[p] = pos;
        }
    }
    pub fn run(&mut self, skip: usize, get: usize) -> String {
        loop {
            if self.scores.len() >= skip + get {
                break;
            }
            self.step();
        }
        let mut got: Vec<char> = Vec::new();
        for p in skip..skip+get {
            for c in self.scores[p].to_string().chars() {
                got.push(c);
            }
        }
        let s: String = got.iter().collect();
        s
    }
    pub fn search(&mut self, wanted: &Vec<u8>) -> usize {
        let wlen = wanted.len();
        let mut len = 2;
        loop {
            let mut found = true;
            let slen = self.scores.len();
            if len < wlen {
                found = false;
            } else {
                for p in 0..wlen {
                    if self.scores[len - wlen + p] != wanted[p] {
                        found = false;
                        break;
                    }
                }
            }
            if found {
                break;
            }
            if len >= slen {
                self.step();
            }
            len += 1;
        }
        len - wlen
    }
    // pub fn print(&self) {
    //     let mut mark: HashMap<usize, usize> = HashMap::new();
    //     for p in 0..self.current.len() {
    //         mark.insert(self.current[p], p);
    //     }
    //     for p in 0..self.scores.len() {
    //         let s = self.scores[p];
    //         if mark.contains_key(&p) {
    //             let m = mark.get(&p).unwrap();
    //             if m % 2 == 0 {
    //                 print!("({})", s);
    //             } else {
    //                 print!("[{}]", s);
    //             }
    //         } else {
    //             print!(" {} ", s);
    //         }
    //     }
    //     println!("");
    // }
}

fn part1(recipe: &mut Recipe, lines: &Vec<Data>) {
    for line in lines {
        let start = Instant::now();
        let s = recipe.run(line.iters, 10);
        let duration = start.elapsed();
        println!("{}: {} ({:?})", line.iters, s, duration);
    }
}

fn part2(recipe: &mut Recipe, lines: &Vec<Data>) {
    for line in lines {
        let start = Instant::now();

        let text = if line.expected.len() > 0 { line.expected.clone() } else { line.iters.to_string() };
        let mut wanted: Vec<u8> = Vec::new();
        for c in text.chars() {
            wanted.push(c as u8 - '0' as u8);
        }
        let count = recipe.search(&wanted);

        let duration = start.elapsed();
        println!("{} => {} ({:?})", text, count, duration);
    }
}

fn main() {
    let lines = read_data();

    let mut initial: Vec<u8> = Vec::new();
    initial.push(3);
    initial.push(7);
    let mut recipe = Recipe::new(&initial);

    part1(&mut recipe, &lines);
    println!("=========");
    part2(&mut recipe, &lines);
}

fn read_data() -> Vec<Data> {
    let mut data = Vec::new();
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let words: Vec<&str> = line.split_whitespace().collect();
        let iters = if words.len() > 0 { words[0].to_string().parse::<usize>().unwrap() } else { 0 };
        if iters <= 0 {
            continue;
        }
        let expected = if words.len() > 1 { words[1] } else { "" };
        data.push(Data::new(iters, expected.to_string()));
    }
    data
}
