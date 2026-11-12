// sidkit: кування відмички (ЛР4, рівні 2 і 3)
use std::env;
use std::fs;
use std::path::Path;

use sha2::{Digest, Sha256};

/// Джерело, з якого приходить seed для ключа.
trait DataSource {
    fn fetch(&self) -> String;
}

/// "Корпоративний сервер ТехНова".
/// Поки це заглушка: seed читаю зі змінної TECHNOVA_SEED,
/// а якщо її нема, беру свій seed з варіанту 2.
struct TechnovaServer;

impl DataSource for TechnovaServer {
    fn fetch(&self) -> String {
        env::var("TECHNOVA_SEED").unwrap_or_else(|_| "techno-b7-gamma".to_string())
    }
}

/// Рівень 2: ключ це SHA-256 від seed у вигляді 64 hex-символів.
fn generate_key(seed: &str) -> String {
    let mut hasher = Sha256::new();
    hasher.update(seed.as_bytes());
    let digest = hasher.finalize();
    digest.iter().map(|b| format!("{b:02x}")).collect()
}

/// Рівень 3: беру seed з будь-якого джерела.
/// Якщо джерело віддало порожній рядок, ключ не роблю (None).
fn generate_key_from_source(source: &dyn DataSource) -> Option<String> {
    let seed = source.fetch();
    let seed = seed.trim();
    if seed.is_empty() {
        None
    } else {
        Some(generate_key(seed))
    }
}

/// Записую ключ у файл key.txt у вказаній папці (том).
fn save_key(dir: &Path, key: &str) -> std::io::Result<()> {
    fs::create_dir_all(dir)?;
    fs::write(dir.join("key.txt"), key)
}

fn main() {
    let server = TechnovaServer;
    let key = match generate_key_from_source(&server) {
        Some(k) => k,
        None => {
            eprintln!("Сервер віддав порожній seed, ключ не зроблено");
            std::process::exit(1);
        }
    };
    println!("Ключ відмички (SHA-256): {key}");

    let dir = env::var("SID_VOLUME").unwrap_or_else(|_| "volume".to_string());
    match save_key(Path::new(&dir), &key) {
        Ok(()) => println!("Ключ записано у {dir}/key.txt"),
        Err(e) => eprintln!("Не вдалося записати ключ: {e}"),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // ---------- рівень 2: sha2 ----------

    #[test]
    fn generate_key_is_deterministic() {
        assert_eq!(generate_key("techno-b7-gamma"), generate_key("techno-b7-gamma"));
    }

    #[test]
    fn generate_key_has_64_hex_chars() {
        let key = generate_key("techno-b7-gamma");
        assert_eq!(key.len(), 64);
        assert!(key.chars().all(|c| c.is_ascii_hexdigit()));
    }

    // відомий тестовий приклад SHA-256 для рядка "abc"
    #[test]
    fn generate_key_matches_known_sha256() {
        assert_eq!(
            generate_key("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        );
    }

    #[test]
    fn generate_key_differs_for_different_seed() {
        assert_ne!(generate_key("techno-b7-gamma"), generate_key("techno-b7-delta"));
    }

    // ---------- рівень 3: мок джерела ----------

    /// Мок замість сервера ТехНова: просто віддає рядок,
    /// який я задав у тесті. Ні мережі, ні диска.
    struct MockSource {
        answer: String,
    }

    impl DataSource for MockSource {
        fn fetch(&self) -> String {
            self.answer.clone()
        }
    }

    fn mock(answer: &str) -> MockSource {
        MockSource { answer: answer.to_string() }
    }

    // успішний сценарій: мок віддав нормальний seed
    #[test]
    fn key_from_mock_source_is_correct() {
        let source = mock("mock-seed-0xC1D");
        assert_eq!(generate_key_from_source(&source), Some(generate_key("mock-seed-0xC1D")));
    }

    // помилковий сценарій: сервер віддав порожній рядок
    #[test]
    fn empty_answer_from_source_gives_no_key() {
        let source = mock("");
        assert_eq!(generate_key_from_source(&source), None);
    }

    // граничний сценарій: тільки пробіли і перенос рядка
    #[test]
    fn whitespace_answer_from_source_gives_no_key() {
        let source = mock("   \n");
        assert_eq!(generate_key_from_source(&source), None);
    }

    // граничний сценарій: зайві пробіли навколо seed не міняють ключ
    #[test]
    fn seed_with_spaces_gives_same_key() {
        let source = mock("  techno-b7-gamma\n");
        assert_eq!(generate_key_from_source(&source), Some(generate_key("techno-b7-gamma")));
    }
}
