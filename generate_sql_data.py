import sqlite3
import numpy as np
import pandas as pd

np.random.seed(7)
conn = sqlite3.connect("retail.db")
cur = conn.cursor()

cur.executescript("""
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    signup_date TEXT,
    region TEXT
);

CREATE TABLE products (
    product_id INTEGER PRIMARY KEY,
    product_name TEXT,
    category TEXT,
    unit_price REAL,
    stock_qty INTEGER
);

CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER,
    order_date TEXT,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_item_id INTEGER PRIMARY KEY,
    order_id INTEGER,
    product_id INTEGER,
    quantity INTEGER,
    FOREIGN KEY (order_id) REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
""")

regions = ["North", "South", "East", "West"]
categories = {
    "Electronics": ["Wireless Earbuds", "Bluetooth Speaker", "Power Bank", "Smartwatch", "USB-C Hub"],
    "Home": ["Table Lamp", "Ceramic Mug Set", "Storage Bin", "Wall Clock", "Cushion Cover Set"],
    "Fitness": ["Yoga Mat", "Resistance Bands", "Water Bottle", "Foam Roller", "Jump Rope"],
    "Stationery": ["Notebook Set", "Desk Organizer", "Sticky Notes Pack", "Gel Pens Set", "Planner"],
}

# products
pid = 1
products = []
for cat, names in categories.items():
    for n in names:
        price = round(np.random.uniform(150, 3500), 2)
        stock = np.random.randint(5, 200)
        products.append((pid, n, cat, price, stock))
        pid += 1
cur.executemany("INSERT INTO products VALUES (?,?,?,?,?)", products)

# customers: signup dates spread over ~15 months
n_customers = 500
start = pd.Timestamp("2024-04-01")
signup_offsets = np.random.randint(0, 480, size=n_customers)
customers = []
for i in range(1, n_customers + 1):
    signup = (start + pd.Timedelta(days=int(signup_offsets[i-1]))).strftime("%Y-%m-%d")
    region = np.random.choice(regions, p=[0.3, 0.25, 0.25, 0.2])
    customers.append((i, signup, region))
cur.executemany("INSERT INTO customers VALUES (?,?,?)", customers)

# orders + order_items
order_id = 1
item_id = 1
orders_rows = []
items_rows = []
END = pd.Timestamp("2025-06-30")

for cust_id, signup_str, region in customers:
    signup = pd.Timestamp(signup_str)
    # customer "activity level" drives how many orders they place after signup
    activity = np.random.choice(["low", "medium", "high"], p=[0.45, 0.35, 0.2])
    n_orders = {"low": np.random.randint(0, 2), "medium": np.random.randint(2, 6), "high": np.random.randint(6, 14)}[activity]
    days_span = max((END - signup).days, 1)
    for _ in range(n_orders):
        order_offset = np.random.randint(0, days_span)
        order_date = (signup + pd.Timedelta(days=int(order_offset))).strftime("%Y-%m-%d")
        orders_rows.append((order_id, cust_id, order_date))
        n_items = np.random.randint(1, 4)
        chosen_products = np.random.choice([p[0] for p in products], size=n_items, replace=False)
        for prod_id in chosen_products:
            qty = np.random.randint(1, 5)
            items_rows.append((item_id, order_id, int(prod_id), int(qty)))
            item_id += 1
        order_id += 1

cur.executemany("INSERT INTO orders VALUES (?,?,?)", orders_rows)
cur.executemany("INSERT INTO order_items VALUES (?,?,?,?)", items_rows)

conn.commit()
print("customers:", len(customers))
print("orders:", len(orders_rows))
print("order_items:", len(items_rows))
print("products:", len(products))
conn.close()
