import 'package:flutter/material.dart';
import '../theme.dart';

class FilterScreen extends StatefulWidget {
  final List<dynamic> categories;
  final List<dynamic> subcategories;
  final List<dynamic> brands;
  final Set<int> initialCategoryIds;
  final Set<int> initialSubcategoryIds;
  final Set<int> initialBrandIds;

  const FilterScreen({
    super.key,
    required this.categories,
    required this.subcategories,
    required this.brands,
    required this.initialCategoryIds,
    required this.initialSubcategoryIds,
    required this.initialBrandIds,
  });

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late Set<int> _selectedCategoryIds;
  late Set<int> _selectedSubcategoryIds;
  late Set<int> _selectedBrandIds;

  @override
  void initState() {
    super.initState();
    _selectedCategoryIds = Set.from(widget.initialCategoryIds);
    _selectedSubcategoryIds = Set.from(widget.initialSubcategoryIds);
    _selectedBrandIds = Set.from(widget.initialBrandIds);
  }

  void _resetAll() {
    setState(() {
      _selectedCategoryIds.clear();
      _selectedSubcategoryIds.clear();
      _selectedBrandIds.clear();
    });
  }

  void _applyFilters() {
    Navigator.pop(context, {
      'categoryIds': _selectedCategoryIds,
      'subcategoryIds': _selectedSubcategoryIds,
      'brandIds': _selectedBrandIds,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    // Dynamically filter active subcategories matching selected categories
    final List<dynamic> activeSubs = _selectedCategoryIds.isEmpty
        ? widget.subcategories
        : widget.subcategories.where((s) => _selectedCategoryIds.contains(s['category_id'])).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAFBFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Filters',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        actions: [
          TextButton(
            onPressed: _resetAll,
            child: const Text(
              'Reset',
              style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Categories Multi-Select
                  const Text(
                    'Categories',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.categories.map((cat) {
                      final int id = cat['id'];
                      final bool isSelected = _selectedCategoryIds.contains(id);
                      return ChoiceChip(
                        label: Text(cat['categories_name'] ?? 'Category'),
                        selected: isSelected,
                        selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                        checkmarkColor: theme.colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? theme.colorScheme.primary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: const Color(0xFFF1F5F9),
                        side: BorderSide(color: isSelected ? theme.colorScheme.primary : Colors.transparent),
                        onSelected: (val) {
                          setState(() {
                            if (val) {
                              _selectedCategoryIds.add(id);
                            } else {
                              _selectedCategoryIds.remove(id);
                              // Clean up child subcategories when parent category is deselected
                              _selectedSubcategoryIds.removeWhere((subId) {
                                final matchingSub = widget.subcategories.firstWhere(
                                  (s) => s['id'] == subId,
                                  orElse: () => null,
                                );
                                return matchingSub != null && matchingSub['category_id'] == id;
                              });
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // 2. Subcategories Multi-Select
                  if (activeSubs.isNotEmpty) ...[
                    const Text(
                      'Subcategories',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: activeSubs.map((sub) {
                        final int id = sub['id'];
                        final bool isSelected = _selectedSubcategoryIds.contains(id);
                        return ChoiceChip(
                          label: Text(sub['categories_subs_name'] ?? 'Subcategory'),
                          selected: isSelected,
                          selectedColor: theme.colorScheme.secondary.withOpacity(0.15),
                          checkmarkColor: theme.colorScheme.secondary,
                          labelStyle: TextStyle(
                            color: isSelected ? theme.colorScheme.secondary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide(color: isSelected ? theme.colorScheme.secondary : Colors.transparent),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedSubcategoryIds.add(id);
                              } else {
                                _selectedSubcategoryIds.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // 3. Brands Multi-Select
                  if (widget.brands.isNotEmpty) ...[
                    const Text(
                      'Brands',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.brands.map((brand) {
                        final int id = brand['id'];
                        final bool isSelected = _selectedBrandIds.contains(id);
                        return ChoiceChip(
                          label: Text(brand['brands_name'] ?? 'Brand'),
                          selected: isSelected,
                          selectedColor: theme.colorScheme.primary.withOpacity(0.15),
                          checkmarkColor: theme.colorScheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected ? theme.colorScheme.primary : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: BorderSide(color: isSelected ? theme.colorScheme.primary : Colors.transparent),
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedBrandIds.add(id);
                              } else {
                                _selectedBrandIds.remove(id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Apply Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Apply Filters',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
