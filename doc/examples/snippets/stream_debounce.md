# Stream Debounce

Prevent rapid UI rebuilds during fast cache updates.

---

## Basic Debounce

```dart
cache.watch<List<Product>>(
  'products',
  debounce: const Duration(milliseconds: 300),
).listen((products) {
  setState(() => _products = products);
});
```

---

## CacheNexusBuilder with Debounce

```dart
CacheNexusBuilder<List<Message>>(
  cache: cache,
  cacheKey: 'messages',
  debounce: const Duration(milliseconds: 500),
  builder: (context, messages) {
    if (messages == null) return const SizedBox();
    return MessageList(messages: messages);
  },
);
```

---

## When to Use Debounce

### Search Results

```dart
// User types in search box
TextField(
  onChanged: (query) {
    // Debounce prevents excessive rebuilds
    cache.watch<List<Product>>(
      'search_$query',
      debounce: const Duration(milliseconds: 300),
    ).listen((products) {
      setState(() => _results = products);
    });
  },
);
```

### Real-Time Data

```dart
// Chat messages arriving rapidly
CacheNexusBuilder<List<Message>>(
  cache: cache,
  cacheKey: 'chat_$conversationId',
  debounce: const Duration(milliseconds: 200),
  builder: (context, messages) {
    if (messages == null) return const SizedBox();
    return ListView.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) => MessageTile(messages[index]),
    );
  },
);
```

### Stock Prices

```dart
// Prices updating every second
CacheNexusBuilder<Map<String, double>>(
  cache: cache,
  cacheKey: 'stock_prices',
  debounce: const Duration(milliseconds: 500),
  builder: (context, prices) {
    if (prices == null) return const SizedBox();
    return StockChart(prices: prices);
  },
);
```

---

## Without Debounce (Bad)

```dart
// Without debounce, UI rebuilds on EVERY update
cache.watch<List<Product>>('products').listen((products) {
  setState(() => _products = products);
});
// If products update 10 times in 1 second,
// UI rebuilds 10 times (laggy!)
```

---

## With Debounce (Good)

```dart
// With debounce, UI rebuilds at most once per 300ms
cache.watch<List<Product>>(
  'products',
  debounce: const Duration(milliseconds: 300),
).listen((products) {
  setState(() => _products = products);
});
// If products update 10 times in 1 second,
// UI rebuilds only 3-4 times (smooth!)
```

---

## Custom Debounce Strategy

```dart
class AdaptiveDebouncer extends StreamTransformerBase<T, T> {
  final Duration initialDelay;
  final Duration maxDelay;

  AdaptiveDebouncer({
    this.initialDelay = const Duration(milliseconds: 100),
    this.maxDelay = const Duration(milliseconds: 1000),
  });

  @override
  Stream<T> bind(Stream<T> stream) {
    // Custom debounce logic
    return stream.debounceTime(maxDelay);
  }
}

// Usage
cache.watch<List<Product>>(
  'products',
  debounce: const Duration(milliseconds: 300),
);
```

---

## Next Snippets

- [Basic CRUD](basic_crud.md)
- [Custom Encryptor](custom_encryptor.md)
- [Cache Warming](cache_warming.md)
