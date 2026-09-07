import 'package:flutter/material.dart';

/// Icons a list can carry, keyed by the name stored in `TaskList.icon`.
const listIconChoices = <String, IconData>{
  'list': Icons.list_alt_rounded,
  'inbox': Icons.inbox_rounded,
  'work': Icons.work_outline_rounded,
  'home': Icons.home_outlined,
  'cart': Icons.shopping_cart_outlined,
  'star': Icons.star_outline_rounded,
  'heart': Icons.favorite_outline_rounded,
  'flight': Icons.flight_takeoff_rounded,
  'school': Icons.school_outlined,
  'fitness': Icons.fitness_center_rounded,
  'book': Icons.menu_book_outlined,
  'idea': Icons.lightbulb_outline_rounded,
};

IconData listIcon(String name) =>
    listIconChoices[name] ?? Icons.list_alt_rounded;
