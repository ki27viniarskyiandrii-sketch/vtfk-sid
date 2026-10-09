fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() > 1 && args[1] == "--pixel" {
        println!("Позивний прийнято. 101.9 FM. Нічна Хвиля на зв'язку.");
        println!("0xC1D підтверджує: пам'ять це відповідальність.");
        return;
    }
    println!("Ядро С.І.Д. активне.");
}
