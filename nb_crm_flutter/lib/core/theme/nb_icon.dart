import 'package:flutter/material.dart';

/// Alias for [Icon] so existing `NbIcon(Icons.foo)` calls are the same
/// `Icon(Icons.foo)` constructor the web icon tree-shaker understands.
typedef NbIcon = Icon;
