import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:food_donation_app/app_router.dart';
import 'package:food_donation_app/models/donation_model.dart';
import 'package:food_donation_app/providers/donation_provider.dart';
import 'package:food_donation_app/theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NgoDiscoveryScreen
//  Toggle between List View and Map View of available food donations.
//  Map markers are colour-coded: red = expiring ≤ 24 h, green = safe.
// ─────────────────────────────────────────────────────────────────────────────
class NgoDiscoveryScreen extends StatefulWidget {
  const NgoDiscoveryScreen({super.key});

  @override
  State<NgoDiscoveryScreen> createState() => _NgoDiscoveryScreenState();
}

class _NgoDiscoveryScreenState extends State<NgoDiscoveryScreen> {
  bool _showMap = false;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  // Search & Filter State
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  String _searchQuery = '';
  String _quantityQuery = '';
  String _locationQuery = '';
  String? _selectedSourceStatus;
  String? _selectedDietaryBase;
  StorageType? _selectedStorageType;
  List<String> _selectedContains = [];
  DateTimeRange? _expiryDateRange;
  DateTimeRange? _pickupDateRange;
  String _sortBy = 'expiry_asc'; // 'expiry_asc', 'expiry_desc', 'newest'
  bool _onlyExpiringSoon = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DonationProvider>().loadAvailableDonations();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ── Build markers from donation list ───────────────────────────────────────
  void _buildMarkers(List<DonationModel> donations) {
    _markers = donations.map((d) {
      final color = d.isExpiringSoon
          ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
          : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

      return Marker(
        markerId: MarkerId(d.id),
        position: LatLng(d.latitude, d.longitude),
        icon: color,
        infoWindow: InfoWindow(
          title: d.foodName,
          snippet:
              '${d.sourceStatus} · ${d.dietaryBase} · ${d.quantity}\n'
              '${d.address ?? 'No address'} · Expires: ${DateFormat('dd MMM, hh:mm a').format(d.expiryDate)}',
          onTap: () => Navigator.of(
            context,
          ).pushNamed(AppRouter.ngoFoodDetail, arguments: d),
        ),
      );
    }).toSet();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final donationProv = context.watch<DonationProvider>();

    // 1. Base list
    var filtered = donationProv.availableDonations;

    // 1.1 Reactive Filter Handling from Provider
    final activeFilter = donationProv.activeFilter;
    if (activeFilter != null) {
      _selectedSourceStatus = activeFilter.sourceStatus;
      _selectedDietaryBase = activeFilter.dietaryBase;
      _onlyExpiringSoon = activeFilter.expiringSoon;
      if (activeFilter.expiringSoon) {
        _sortBy = 'expiry_asc';
      }
      // Clear it from provider once consumed so it doesn't keep overriding user choices
      WidgetsBinding.instance.addPostFrameCallback((_) {
        donationProv.clearActiveFilter();
      });
    }

    // 2. Search filtering
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((d) {
        return d.foodName.toLowerCase().contains(query) ||
            d.donorName.toLowerCase().contains(query);
      }).toList();
    }

    // 3. Status/Dietary/Storage filtering
    if (_selectedSourceStatus != null) {
      filtered = filtered
          .where((d) => d.sourceStatus == _selectedSourceStatus)
          .toList();
    }
    if (_selectedDietaryBase != null) {
      filtered = filtered.where((d) {
        if (_selectedDietaryBase == DietaryBase.vegetarian) {
          return d.dietaryBase == DietaryBase.vegetarian ||
              d.dietaryBase == DietaryBase.vegan;
        }
        return d.dietaryBase == _selectedDietaryBase;
      }).toList();
    }
    if (_selectedStorageType != null) {
      filtered = filtered
          .where((d) => d.storageType == _selectedStorageType)
          .toList();
    }

    // 4. contains logic (Item must have AT LEAST ONE of the selected tags to match)
    if (_selectedContains.isNotEmpty) {
      filtered = filtered.where((d) {
        return _selectedContains.any((tag) => d.contains.contains(tag));
      }).toList();
    }

    // 4.1 Expiring soon filter
    if (_onlyExpiringSoon) {
      filtered = filtered.where((d) => d.isExpiringSoon).toList();
    }

    // 5. Quantity and Location String matching
    if (_quantityQuery.isNotEmpty) {
      final qQuery = _quantityQuery.toLowerCase();
      filtered = filtered
          .where((d) => d.quantity.toLowerCase().contains(qQuery))
          .toList();
    }

    if (_locationQuery.isNotEmpty) {
      final lQuery = _locationQuery.toLowerCase();
      filtered = filtered.where((d) {
        // Fallback to empty string if address is null to safely skip.
        return (d.address ?? '').toLowerCase().contains(lQuery);
      }).toList();
    }

    // 6. Date Range Filtering
    if (_expiryDateRange != null) {
      filtered = filtered.where((d) {
        // True if the date is within the date bounds
        return d.expiryDate.isAfter(_expiryDateRange!.start) &&
            d.expiryDate.isBefore(
              _expiryDateRange!.end.add(const Duration(days: 1)),
            );
      }).toList();
    }

    if (_pickupDateRange != null) {
      filtered = filtered.where((d) {
        // True if the pickup window interacts with the selected date block.
        // We define overlapping as: max(start1, start2) <= min(end1, end2)
        final DateTime rangeEnd = _pickupDateRange!.end.add(
          const Duration(days: 1),
        ); // inclusive of the final day
        return (d.pickupStart.isBefore(rangeEnd)) &&
            (d.pickupEnd.isAfter(_pickupDateRange!.start));
      }).toList();
    }

    // 7. Sorting
    filtered.sort((a, b) {
      final aDate = a.expiryDate;
      final bDate = b.expiryDate;

      return switch (_sortBy) {
        'expiry_desc' => bDate.compareTo(aDate),
        'newest' => (b.createdAt ?? DateTime.now()).compareTo(
          a.createdAt ?? DateTime.now(),
        ),
        _ => aDate.compareTo(bDate), // default 'expiry_asc'
      };
    });

    final donations = filtered;

    // Rebuild markers whenever the list changes
    if (_showMap) _buildMarkers(donations);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Food'),
        automaticallyImplyLeading: false,
        actions: [
          // Map / List toggle
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                selectedForegroundColor: Theme.of(
                  context,
                ).colorScheme.onSurface,
              ),
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.list_rounded, size: 18),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.map_outlined, size: 18),
                ),
              ],
              selected: {_showMap},
              onSelectionChanged: (s) => setState(() => _showMap = s.first),
            ),
          ),
        ],
      ),
      body: donationProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ── Search & Filter header ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search food or donor...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (val) =>
                              setState(() => _searchQuery = val),
                        ),
                      ),
                      const Gap(12),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.tune_rounded),
                          color: Theme.of(context).colorScheme.onPrimary,
                          tooltip: 'Filter & Sort',
                          onPressed: () => _showFilterBottomSheet(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Active Filters chips ───────────────────────────────────────
                if (_selectedSourceStatus != null ||
                    _selectedDietaryBase != null ||
                    _onlyExpiringSoon ||
                    _sortBy != 'expiry_asc')
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 8,
                    ),
                    child: SizedBox(
                      height: 32,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          if (_sortBy != 'expiry_asc')
                            _ActiveFilterChip(
                              label: _sortBy == 'expiry_desc'
                                  ? 'Latest Expiry'
                                  : 'Newest Listed',
                              onClear: () =>
                                  setState(() => _sortBy = 'expiry_asc'),
                            ),

                          if (_onlyExpiringSoon)
                            _ActiveFilterChip(
                              label: 'Expiring Soon',
                              onClear: () =>
                                  setState(() => _onlyExpiringSoon = false),
                            ),

                          // Quantity & Location
                          if (_quantityQuery.isNotEmpty)
                            _ActiveFilterChip(
                              label: 'Qty: $_quantityQuery',
                              onClear: () {
                                _quantityController.clear();
                                setState(() => _quantityQuery = '');
                              },
                            ),
                          if (_locationQuery.isNotEmpty)
                            _ActiveFilterChip(
                              label: 'Loc: $_locationQuery',
                              onClear: () {
                                _locationController.clear();
                                setState(() => _locationQuery = '');
                              },
                            ),

                          // Enums & String matchers
                          if (_selectedSourceStatus != null)
                            _ActiveFilterChip(
                              label: _selectedSourceStatus!.toUpperCase(),
                              onClear: () =>
                                  setState(() => _selectedSourceStatus = null),
                            ),
                          if (_selectedDietaryBase != null)
                            _ActiveFilterChip(
                              label: _selectedDietaryBase!.toUpperCase(),
                              onClear: () =>
                                  setState(() => _selectedDietaryBase = null),
                            ),
                          if (_selectedStorageType != null)
                            _ActiveFilterChip(
                              label: _selectedStorageType!.displayLabel
                                  .toUpperCase(),
                              onClear: () =>
                                  setState(() => _selectedStorageType = null),
                            ),

                          // Contains Multi-select
                          for (final tag in _selectedContains)
                            _ActiveFilterChip(
                              label: tag.toUpperCase(),
                              onClear: () =>
                                  setState(() => _selectedContains.remove(tag)),
                            ),

                          // Date Ranges
                          if (_expiryDateRange != null)
                            _ActiveFilterChip(
                              label:
                                  'Exp: ${DateFormat('MMM d').format(_expiryDateRange!.start)}-${DateFormat('MMM d').format(_expiryDateRange!.end)}',
                              onClear: () =>
                                  setState(() => _expiryDateRange = null),
                            ),
                          if (_pickupDateRange != null)
                            _ActiveFilterChip(
                              label:
                                  'Pickup: ${DateFormat('MMM d').format(_pickupDateRange!.start)}-${DateFormat('MMM d').format(_pickupDateRange!.end)}',
                              onClear: () =>
                                  setState(() => _pickupDateRange = null),
                            ),
                        ],
                      ),
                    ),
                  ),

                // ── Map or List view ───────────────────────────────────────────
                Expanded(
                  child: _showMap
                      ? _buildMapView(donations)
                      : _buildListView(donations),
                ),
              ],
            ),
    );
  }

  // ── Bottom Sheet for Filter & Sort ─────────────────────────────────────────
  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final bottomPadding = MediaQuery.of(modalContext).viewInsets.bottom;
            final donationProv = modalContext.read<DonationProvider>();

            return Container(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filter & Sort',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              _selectedSourceStatus = null;
                              _selectedDietaryBase = null;
                              _selectedStorageType = null;
                              _selectedContains.clear();
                              _quantityController.clear();
                              _locationController.clear();
                              _quantityQuery = '';
                              _locationQuery = '';
                              _expiryDateRange = null;
                              _pickupDateRange = null;
                              _sortBy = 'expiry_asc';
                              _onlyExpiringSoon = false;
                            });
                            donationProv.clearActiveFilter();
                            setState(() {});
                          },
                          child: const Text('Clear All'),
                        ),
                      ],
                    ),
                    const Gap(16),

                    // Sort By
                    Text(
                      'Sort By',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(8),
                    DropdownButtonFormField<String>(
                      value: _sortBy,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'expiry_asc',
                          child: Text('Expiring Earliest'),
                        ),
                        DropdownMenuItem(
                          value: 'expiry_desc',
                          child: Text('Expiring Latest'),
                        ),
                        DropdownMenuItem(
                          value: 'newest',
                          child: Text('Newest Listings'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => _sortBy = val);
                          setState(() {});
                        }
                      },
                    ),
                    const Gap(24),

                    // Filter: Source Status
                    Text(
                      'Source Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(8),
                    Wrap(
                      spacing: 8,
                      children: DietarySourceStatus.all.map((status) {
                        final isSelected = _selectedSourceStatus == status;
                        return FilterChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedSourceStatus = selected ? status : null;
                            });
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const Gap(24),

                    // Filter: Dietary Base
                    Text(
                      'Dietary Base',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(8),
                    Wrap(
                      spacing: 8,
                      children: DietaryBase.all.map((base) {
                        final isSelected = _selectedDietaryBase == base;
                        return FilterChip(
                          label: Text(base),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedDietaryBase = selected ? base : null;
                            });
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const Gap(24),

                    // Filter: Dietary Contains (Multi-select)
                    Text(
                      'Contains / Allergens',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(8),
                    Wrap(
                      spacing: 8,
                      children: DietaryContains.all.map((tag) {
                        final isSelected = _selectedContains.contains(tag);
                        return FilterChip(
                          label: Text(tag),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              if (selected) {
                                _selectedContains.add(tag);
                              } else {
                                _selectedContains.remove(tag);
                              }
                            });
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const Gap(24),

                    // Filter: Storage Type
                    Text(
                      'Storage Requirement',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(8),
                    Wrap(
                      spacing: 8,
                      children: StorageType.values.map((type) {
                        final isSelected = _selectedStorageType == type;
                        return FilterChip(
                          label: Text(type.displayLabel),
                          selected: isSelected,
                          onSelected: (selected) {
                            setModalState(() {
                              _selectedStorageType = selected ? type : null;
                            });
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const Gap(24),

                    // Filter: Quantity & Location Text Searches
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Quantity',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const Gap(8),
                              TextField(
                                controller: _quantityController,
                                decoration: InputDecoration(
                                  hintText: 'e.g. 50 pax',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onChanged: (val) {
                                  setModalState(() => _quantityQuery = val);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                        const Gap(16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const Gap(8),
                              TextField(
                                controller: _locationController,
                                decoration: InputDecoration(
                                  hintText: 'City, Area...',
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onChanged: (val) {
                                  setModalState(() => _locationQuery = val);
                                  setState(() {});
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Gap(24),

                    // Filter: Date Ranges
                    Text(
                      'Date Filters',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.event_available_rounded,
                              size: 18,
                            ),
                            label: Text(
                              _expiryDateRange == null
                                  ? 'Expiry Range'
                                  : '${DateFormat('MMM d').format(_expiryDateRange!.start)} - ${DateFormat('MMM d').format(_expiryDateRange!.end)}',
                            ),
                            onPressed: () async {
                              final range = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 365),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365 * 2),
                                ),
                                initialDateRange: _expiryDateRange,
                              );
                              if (range != null) {
                                setModalState(() => _expiryDateRange = range);
                                setState(() {});
                              }
                            },
                          ),
                        ),
                        if (_expiryDateRange != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setModalState(() => _expiryDateRange = null);
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                    const Gap(8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(
                              Icons.local_shipping_outlined,
                              size: 18,
                            ),
                            label: Text(
                              _pickupDateRange == null
                                  ? 'Pickup Window'
                                  : '${DateFormat('MMM d').format(_pickupDateRange!.start)} - ${DateFormat('MMM d').format(_pickupDateRange!.end)}',
                            ),
                            onPressed: () async {
                              final range = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 365),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365 * 2),
                                ),
                                initialDateRange: _pickupDateRange,
                              );
                              if (range != null) {
                                setModalState(() => _pickupDateRange = range);
                                setState(() {});
                              }
                            },
                          ),
                        ),
                        if (_pickupDateRange != null)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setModalState(() => _pickupDateRange = null);
                              setState(() {});
                            },
                          ),
                      ],
                    ),
                    const Gap(32),

                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Apply Options'),
                    ),
                    const Gap(16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── Map view ───────────────────────────────────────────────────────────────
  Widget _buildMapView(List<DonationModel> donations) {
    // Default camera: Malaysia centre
    const defaultPosition = LatLng(4.2105, 101.9758);

    // Centre on first listing if available
    final initialTarget = donations.isNotEmpty
        ? LatLng(donations.first.latitude, donations.first.longitude)
        : defaultPosition;

    return Stack(
      children: [
        GoogleMap(
          onMapCreated: (c) => _mapController = c,
          initialCameraPosition: CameraPosition(
            target: initialTarget,
            zoom: donations.isNotEmpty ? 13.0 : 6.5,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
        ),
        // Legend overlay
        Positioned(top: 12, left: 12, child: _MapLegend()),
        if (donations.isEmpty)
          const Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No available donations to show on map.'),
              ),
            ),
          ),
      ],
    );
  }

  // ── List view ──────────────────────────────────────────────────────────────
  Widget _buildListView(List<DonationModel> donations) {
    if (donations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 56, color: Colors.black26),
            Gap(12),
            Text(
              'No food available right now.\nCheck back soon!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black45),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<DonationProvider>().loadAvailableDonations();
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: donations.length,
        itemBuilder: (_, i) => _DonationListCard(donation: donations[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _DonationListCard
// ─────────────────────────────────────────────────────────────────────────────
class _DonationListCard extends StatelessWidget {
  final DonationModel donation;
  const _DonationListCard({required this.donation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final expiryColor = donation.isExpiringSoon
        ? AppTheme.statusExpiringSoon
        : AppTheme.statusCompleted;

    return Card(
      child: InkWell(
        borderRadius: AppTheme.radiusMd,
        onTap: () => Navigator.of(
          context,
        ).pushNamed(AppRouter.ngoFoodDetail, arguments: donation),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Food type icon pill ────────────────────────────────────
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.fastfood_rounded, color: colorScheme.primary),
              ),
              const Gap(12),

              // ── Details ────────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donation.foodName,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(4),
                    Text(
                      '${donation.sourceStatus} · ${donation.dietaryBase} · ${donation.quantity}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                    const Gap(4),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 13,
                          color: expiryColor,
                        ),
                        const Gap(4),
                        Text(
                          'Expires: ${DateFormat('dd MMM, hh:mm a').format(donation.expiryDate)}',
                          style: textTheme.labelSmall?.copyWith(
                            color: expiryColor,
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 13,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const Gap(4),
                        Text(
                          donation.donorName,
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    if (donation.address != null) ...[
                      const Gap(4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const Gap(4),
                          Expanded(
                            child: Text(
                              donation.address!,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Gap(8),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _MapLegend
// ─────────────────────────────────────────────────────────────────────────────
class _MapLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendItem(color: Colors.red, label: 'Expiring ≤ 24h'),
            const Gap(4),
            _LegendItem(color: Colors.green, label: 'Safe'),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const Gap(6),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;
  const _ActiveFilterChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        height: 32,
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(4),
            InkWell(
              onTap: onClear,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
