#!/usr/bin/env python3
"""
Generates a 200-item mock marketplace listings JSON file.
Run: python3 generate_mock_listings.py
Output: ../Resources/listings_200.json

Uses picsum.photos deterministic seeded URLs so every listing has a REAL,
resolvable image (good for demoing caching/downsampling honestly), plus
a couple of thumbnail sizes so the app can request the right resolution
per context (grid cell vs detail view) instead of always pulling full-size.
"""
import json
import random
import uuid
from datetime import datetime, timedelta

random.seed(42)

CATEGORIES = ["Electronics", "Furniture", "Clothing", "Books", "Sports", "Toys", "Home & Garden", "Automotive"]
ADJECTIVES = ["Vintage", "Modern", "Refurbished", "Brand New", "Like New", "Rare", "Handmade", "Compact"]
SELLERS = [f"seller_{i}" for i in range(1, 25)]

CONDITIONS = ["new", "like_new", "good", "fair"]

def make_listing(i: int) -> dict:
    category = CATEGORIES[i % len(CATEGORIES)]
    adjective = random.choice(ADJECTIVES)
    created = datetime(2026, 1, 1) + timedelta(days=random.randint(0, 220), minutes=random.randint(0, 1000))
    updated = created + timedelta(hours=random.randint(0, 72))
    seed = i  # deterministic image per listing

    # a couple of edge cases sprinkled in on purpose, to exercise defensive
    # decoding / empty-state UI during the demo:
    description = f"{adjective} {category.lower()} item, well cared for. Listing #{i}."
    if i % 47 == 0:
        description = ""  # empty description edge case
    image_url = f"https://picsum.photos/seed/{seed}/800/800"
    thumb_url = f"https://picsum.photos/seed/{seed}/300/300"
    if i % 61 == 0:
        image_url = ""  # missing image edge case

    return {
        "id": str(uuid.uuid5(uuid.NAMESPACE_URL, f"listing-{i}")),
        "title": f"{adjective} {category} Item #{i}",
        "description": description,
        "price": round(random.uniform(5, 899), 2),
        "currency": "CAD",
        "category": category,
        "condition": random.choice(CONDITIONS),
        "imageURL": image_url,
        "thumbnailURL": thumb_url,
        "sellerId": random.choice(SELLERS),
        "location": random.choice(["Toronto, ON", "Barrie, ON", "Ottawa, ON", "Mississauga, ON", "Hamilton, ON"]),
        "createdAt": created.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "updatedAt": updated.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "isFavorite": False,
        "version": 1
    }

def main():
    listings = [make_listing(i) for i in range(1, 201)]
    payload = {
        "meta": {
            "count": len(listings),
            "generatedAt": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
            "source": "mock-json-generator"
        },
        "listings": listings
    }
    out_path = "../Resources/listings_200.json"
    with open(out_path, "w") as f:
        json.dump(payload, f, indent=2)
    print(f"Wrote {len(listings)} listings to {out_path}")

if __name__ == "__main__":
    main()
