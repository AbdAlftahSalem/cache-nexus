class Todo {
  final String id;
  final String title;
  final bool completed;

  const Todo({required this.id, required this.title, this.completed = false});

  Todo copyWith({String? id, String? title, bool? completed}) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      completed: completed ?? this.completed,
    );
  }

  factory Todo.fromJson(Map<String, dynamic> json) {
    return Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      completed: json['completed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title, 'completed': completed};
  }
}
