# Капсула С.І.Д.: багатоетапна збірка до scratch (контекст це корінь vtfk-sid)
FROM rust:1.79 AS build
WORKDIR /app
# ціль musl: бінарник буде статичний, без libc системи
RUN rustup target add x86_64-unknown-linux-musl
# 1) спершу тільки маніфест і lock, залежності збираються окремим шаром
COPY core/sid/Cargo.toml core/sid/Cargo.lock ./
RUN mkdir src && echo "fn main() {}" > src/main.rs && cargo build --release --target x86_64-unknown-linux-musl && rm -rf src
# 2) потім прикладний код, його зміна ламає кеш тільки звідси
COPY core/sid/ ./
RUN touch src/main.rs && cargo build --release --target x86_64-unknown-linux-musl

# привид: порожній образ і один файл
FROM scratch
COPY --from=build /app/target/x86_64-unknown-linux-musl/release/vtfk-sid /vtfk-sid
ENTRYPOINT ["/vtfk-sid"]
