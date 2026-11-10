create table orders (
    order_id    uuid primary key,
    shop        text not null,
    customer_id int not null,
    total       int not null,
    payment_id  text not null,
    created_at  timestamptz not null default now()
);

create table charges (
    payment_id text primary key,
    order_id   uuid not null,
    shop       text not null,
    amount     int not null,
    created_at timestamptz not null default now()
);

create index on charges (created_at);
