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

  int _activeTab = 0; // 0: Categories, 1: Subcategories, 2: Brands
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCategoryIds = Set.from(widget.initialCategoryIds);
    _selectedSubcategoryIds = Set.from(widget.initialSubcategoryIds);
    _selectedBrandIds = Set.from(widget.initialBrandIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetAll() {
    setState(() {
      _selectedCategoryIds.clear();
      _selectedSubcategoryIds.clear();
      _selectedBrandIds.clear();
      _searchText = '';
      _searchController.clear();
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

    // Compute details list based on active tab
    List<dynamic> currentOptionsList = [];
    String searchPlaceholder = '';

    if (_activeTab == 0) {
      currentOptionsList = widget.categories;
      searchPlaceholder = 'Search categories...';
    } else if (_activeTab == 1) {
      currentOptionsList = activeSubs;
      searchPlaceholder = 'Search subcategories...';
    } else {
      currentOptionsList = widget.brands;
      searchPlaceholder = 'Search brands...';
    }

    // Filter current list options based on search query
    if (_searchText.isNotEmpty) {
      currentOptionsList = currentOptionsList.where((opt) {
        final String name = (_activeTab == 0
            ? opt['categories_name']
            : _activeTab == 1
                ? opt['categories_subs_name']
                : opt['brands_name'])?.toString().toLowerCase() ?? '';
        return name.contains(_searchText.toLowerCase());
      }).toList();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Filters',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 0.3,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.border,
            height: 1.0,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. LEFT SIDEBAR (Tabs Menu)
                Container(
                  width: 140,
                  color: const Color(0xFFF6F7F9),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _buildSidebarTab(
                        index: 0,
                        title: 'Categories',
                        selectedCount: _selectedCategoryIds.length,
                      ),
                      _buildSidebarTab(
                        index: 1,
                        title: 'Subcategories',
                        selectedCount: _selectedSubcategoryIds.length,
                        enabled: activeSubs.isNotEmpty,
                      ),
                      _buildSidebarTab(
                        index: 2,
                        title: 'Brands',
                        selectedCount: _selectedBrandIds.length,
                        enabled: widget.brands.isNotEmpty,
                      ),
                    ],
                  ),
                ),

                // Vertical Divider line between menus
                Container(
                  width: 1,
                  color: AppColors.border,
                ),

                // 2. RIGHT DETAILS PANEL
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search bar inside options list
                        Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              setState(() {
                                _searchText = val;
                              });
                            },
                            decoration: InputDecoration(
                              hintText: searchPlaceholder,
                              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
                              prefixIcon: const Icon(Icons.search, color: AppColors.textLight, size: 18),
                              suffixIcon: _searchText.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 16, color: AppColors.textLight),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchText = '';
                                        });
                                      },
                                    )
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              fillColor: const Color(0xFFF1F5F9),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: theme.colorScheme.primary.withOpacity(0.3), width: 1),
                              ),
                            ),
                          ),
                        ),

                        // Scrollable Checklist
                        Expanded(
                          child: currentOptionsList.isEmpty
                              ? Center(
                                  child: Text(
                                    _searchText.isNotEmpty ? 'No matches found' : 'No options available',
                                    style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  itemCount: currentOptionsList.length,
                                  itemBuilder: (context, index) {
                                    final item = currentOptionsList[index];
                                    final int id = item['id'];
                                    
                                    bool isSelected = false;
                                    String optionName = '';
                                    
                                    if (_activeTab == 0) {
                                      isSelected = _selectedCategoryIds.contains(id);
                                      optionName = item['categories_name'] ?? 'Category';
                                    } else if (_activeTab == 1) {
                                      isSelected = _selectedSubcategoryIds.contains(id);
                                      optionName = item['categories_subs_name'] ?? 'Subcategory';
                                    } else {
                                      isSelected = _selectedBrandIds.contains(id);
                                      optionName = item['brands_name'] ?? 'Brand';
                                    }

                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (_activeTab == 0) {
                                            if (isSelected) {
                                              _selectedCategoryIds.remove(id);
                                              // Remove subcategories belonging to this category
                                              _selectedSubcategoryIds.removeWhere((subId) {
                                                final matchingSub = widget.subcategories.firstWhere(
                                                  (s) => s['id'] == subId,
                                                  orElse: () => null,
                                                );
                                                return matchingSub != null && matchingSub['category_id'] == id;
                                              });
                                            } else {
                                              _selectedCategoryIds.add(id);
                                            }
                                          } else if (_activeTab == 1) {
                                            if (isSelected) {
                                              _selectedSubcategoryIds.remove(id);
                                            } else {
                                              _selectedSubcategoryIds.add(id);
                                            }
                                          } else {
                                            if (isSelected) {
                                              _selectedBrandIds.remove(id);
                                            } else {
                                              _selectedBrandIds.add(id);
                                            }
                                          }
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        child: Row(
                                          children: [
                                            // Checkbox widget
                                            Container(
                                              width: 20,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                                                borderRadius: BorderRadius.circular(5),
                                                border: Border.all(
                                                  color: isSelected ? theme.colorScheme.primary : AppColors.textMuted,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: isSelected
                                                  ? const Icon(
                                                      Icons.check,
                                                      size: 14,
                                                      color: Colors.white,
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 14),
                                            // Label Option
                                            Expanded(
                                              child: Text(
                                                optionName,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                  color: isSelected ? AppColors.textPrimary : AppColors.textLight,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action bar containing Clear & Apply buttons
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom + 12
                  : 16,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Clear all button (Outlined Style)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetAll,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textLight,
                      side: const BorderSide(color: AppColors.border, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Clear All',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Apply filters button (Solid Accent style)
                Expanded(
                  child: ElevatedButton(
                    onPressed: _applyFilters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Apply Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarTab({
    required int index,
    required String title,
    required int selectedCount,
    bool enabled = true,
  }) {
    if (!enabled) return const SizedBox.shrink();

    final bool isActive = _activeTab == index;
    final theme = Theme.of(context);

    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = index;
          _searchText = '';
          _searchController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : const Color(0xFFF6F7F9),
        ),
        child: Row(
          children: [
            // Selection indicator vertical bar
            if (isActive)
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
            else
              const SizedBox(width: 4),
            const SizedBox(width: 8),
            // Title & selection counts
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w900 : FontWeight.w600,
                      color: isActive ? AppColors.textPrimary : AppColors.textLight,
                    ),
                  ),
                  if (selectedCount > 0) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$selectedCount selected',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
