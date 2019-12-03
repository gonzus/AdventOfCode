use std::io::{self, BufRead};
use std::collections::HashMap;

#[derive(Debug)]
struct Info {
    players: usize,
    last: usize,
    high: usize,
}
impl Info {
    pub fn new(players: usize, last: usize, high: usize) -> Info {
        Info{ players, last, high }
    }
}

fn main() {
    let infos = read_lines();
    for info in infos {
        play(&info, 1);
        play(&info, 100);
    }
}

fn read_lines() -> Vec<Info> {
    let mut infos = Vec::new();
    let stdin = io::stdin();
    for line in stdin.lock().lines() {
        let line = line.unwrap();
        let words: Vec<&str> = line.split_whitespace().collect();
        let players = words[0].to_string().parse::<usize>().unwrap();
        let last = words[6].to_string().parse::<usize>().unwrap();
        let high = if words.len() > 11 { words[11].to_string().parse::<usize>().unwrap() } else { 0 };
        let info = Info::new(players, last, high);
        infos.push(info);
    }
    infos
}

#[derive(Debug)]
struct Board {
    board: Vec<usize>,
    next: Vec<usize>,
    prev: Vec<usize>,
    current: usize,
    score: HashMap<usize, usize>,
}
impl Board {
    pub fn new() -> Board {
        let mut board = Board{
            board: Vec::new(),
            next: Vec::new(),
            prev: Vec::new(),
            current: 0,
            score: HashMap::new(),
        };
        board.board.push(0);
        board.next.push(0);
        board.prev.push(0);
        board
    }
    fn add_node_after(&mut self, pos: usize, value: usize) {
        let next = self.next[pos];
        let newpos = self.board.len();
        self.board.push(value);
        self.prev.push(pos);
        self.next.push(next);
        self.next[pos] = newpos;
        self.prev[next] = newpos;
    }
    fn remove_node(&mut self, pos: usize) {
        let prev = self.prev[pos];
        let next = self.next[pos];
        self.next[prev] = next;
        self.prev[next] = prev;
    }
    pub fn add_marble(&mut self, player: usize, marble: usize) -> usize {
        let mut pos = self.current;
        if marble % 23 == 0 {
            for _ in 0..7 {
                pos = self.prev[pos];
            }
            self.current = self.next[pos];
            let removed = self.board[pos];
            self.remove_node(pos);
            let points = marble + removed;
            let score = self.score.entry(player).or_insert(0);
            *score += points;
        } else {
            pos = self.next[pos];
            self.add_node_after(pos, marble);
            self.current = self.next[pos];
        }
        marble
    }
    pub fn print(&self, player: usize) {
        print!("[{}]", player);
        let mut pos = 0;
        loop {
            let marble = self.board[pos];
            if pos == self.current {
                print!(" ({})", marble);
            } else {
                print!(" {}", marble);
            }
            pos = self.next[pos];
            if pos == 0 {
                break;
            }
        }
        println!("");
    }
}

fn play(info: &Info, factor: usize) {
    // println!("info {:?}", info);
    let mut board = Board::new();
    let mut player = 1;
    let mut marble = 1;
    let last = info.last * factor;

    loop {
        let points = board.add_marble(player, marble);
        // board.print(player);
        if points == last {
            println!("Found last {}", points);
            let mut top_score = 0;
            let mut top_player = 0;
            for (player, score) in board.score {
                // println!("player {} => {}", player, score);
                if top_score < score {
                    top_score = score;
                    top_player = player;
                }
            }
            print!("Player {} wins with {}", top_player, top_score);
            if info.high > 0 {
                print!(", expected {}", info.high);
            }
            println!("");
            break;
        }
        player = player % info.players + 1;
        marble += 1;
    }
}
