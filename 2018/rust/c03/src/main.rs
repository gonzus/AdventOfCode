extern crate regex;

use std::collections::HashMap;
use std::io::{self, BufRead};
use regex::Regex;

struct Claim {
    id: i32,
    x: i32,
    y: i32,
    w: i32,
    h: i32,
}

fn main() {
    let claims = read_claims();
    println!("{} claims", claims.len());

    let grid = fill_grid(&claims);
    println!("{} squares", grid.len());

    find_bad_squares(&grid);
    find_good_claims(&claims, &grid);
}

fn read_claims() -> Vec<Claim> {
    let re = Regex::new(
        r#"(?x)
          [\#]
          ([0-9]+)      # id
          \s*
          [@]
          \s*
          ([0-9]+)[,]([0-9]+)  # x, y
          \s*
          [:]
          \s*
          ([0-9]+)[x]([0-9]+)  # w, h
          \s*
          "#).unwrap();

    let mut claims = Vec::new();
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let caps = re.captures(line.as_str()).unwrap();
        let claim = Claim {
            id: get_match_int(&caps, 1),
            x: get_match_int(&caps, 2),
            y: get_match_int(&caps, 3),
            w: get_match_int(&caps, 4),
            h: get_match_int(&caps, 5),
        };
        claims.push(claim);
    }
    claims
}

fn get_match_int(caps: &regex::Captures, pos: usize) -> i32 {
    caps.get(pos).map_or("", |m| m.as_str()).parse::<i32>().unwrap()
}

fn fill_grid(claims: &Vec<Claim>) -> HashMap<(i32, i32), u32> {
    let mut grid = HashMap::new();
    for claim in claims {
        for xpos in claim.x..(claim.x+claim.w) {
            for ypos in claim.y..(claim.y+claim.h) {
                let key = (xpos, ypos);
                let mut cnt = match grid.get(&key) {
                    Some(&number) => number,
                    _ => 0,
                };
                cnt += 1;
                grid.insert(key, cnt);
            }
        }
    }
    grid
}

fn find_bad_squares(grid: &HashMap<(i32, i32), u32>) {
    let mut squares = 0;
    for (_key, cnt) in grid {
        // println!("{} {} {}", _key.0, _key.1, cnt);
        if *cnt < 2 {
            continue;
        }
        squares += 1;
    }
    println!("{} bad squares", squares);
}

fn find_good_claims(claims: &Vec<Claim>, grid: &HashMap<(i32, i32), u32>) {
    'claim: for claim in claims {
        for xpos in claim.x..(claim.x+claim.w) {
            for ypos in claim.y..(claim.y+claim.h) {
                let key = (xpos, ypos);
                let mut cnt = match grid.get(&key) {
                    Some(&number) => number,
                    _ => 0,
                };
                if cnt > 1 {
                    continue 'claim;
                }
            }
        }
        println!("{} id OK", claim.id);
    }
}
