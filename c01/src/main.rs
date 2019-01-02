use std::io::{self, BufRead};
use std::collections::HashMap;

fn main() {
    let mut lines = Vec::new();
    let stdin = io::stdin();

    // read all of stdin and convert to a number array
    // TODO: this can probably made more idiomatic
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        match line.parse::<i32>() {
            Ok(num) => lines.push(num),
            Err(_) => println!("That was not a number: {}", line),
        }
    }

    let mut count = 0;
    let mut total = 0;

    total = 0;
    count = 0;
    for num in lines.iter() {
        total += num;
        count += 1;
    }
    println!("p1: {} ({})", total, count);

    total = 0;
    count = 0;
    let mut seen = HashMap::new();
    'seen: loop {
        for num in lines.iter() {
            total += num;
            if seen.contains_key(&total) {
                break 'seen;
            }
            seen.insert(total, 1);
            count += 1;
        }
    }
    println!("p2: {} ({})", total, count);
}
