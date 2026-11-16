import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routing/app_routes.dart';
import '../theme/app_theme.dart';
import '../theme/widgets/app_input_decoration.dart';

/// Seções do Explorar.
enum ExploreSection { lost, found, adoption }

/// Estrutura visual comum às listas do Explorar (perdidos, encontrados e
/// adoção): título, seções, busca, abas "público / meus", filtros de espécie
/// e a grade de pets. Apenas visual: os dados e ações vêm de cada tela.
class ExploreLayout extends StatelessWidget {
  final ExploreSection section;

  // Busca
  final TextEditingController searchController;
  final String query;
  final String searchHint;
  final ValueChanged<String> onQueryChanged;

  // Abas "Feed público / Meus ..."
  final int tab;
  final List<String> tabLabels;
  final ValueChanged<int> onTabChanged;

  // Filtros de espécie (rótulos e qual está marcado; -1 = Todos)
  final List<String> filterLabels;
  final int selectedFilter;
  final ValueChanged<int> onFilterChanged;

  /// Rota do mapa desta seção (null = sem botão de mapa).
  final String? mapRoute;
  final VoidCallback onRefresh;

  /// Monta a grade recebendo a margem lateral usada na tela.
  final Widget Function(double horizontalPadding) bodyBuilder;

  const ExploreLayout({
    super.key,
    required this.section,
    required this.searchController,
    required this.query,
    required this.searchHint,
    required this.onQueryChanged,
    required this.tab,
    required this.tabLabels,
    required this.onTabChanged,
    required this.filterLabels,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onRefresh,
    required this.bodyBuilder,
    this.mapRoute,
  });

  /// Largura máxima do conteúdo no PC (igual às outras telas).
  static const double maxContent = 1120;

  /// Grade padrão de cartões de pet.
  static const gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: 240,
    mainAxisSpacing: 16,
    crossAxisSpacing: 16,
    childAspectRatio: 0.74,
  );

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    final hPad = isDesktop ? 40.0 : 20.0;

    final searchField = TextField(
      controller: searchController,
      onChanged: onQueryChanged,
      decoration: AppInputDecoration.defaultDecoration(
        labelText: '',
        hintText: searchHint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        isSearch: true,
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar busca',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  searchController.clear();
                  onQueryChanged('');
                },
              ),
      ),
    );

    final tabs = _SegmentedTabs(
      index: tab,
      labels: tabLabels,
      onChanged: onTabChanged,
    );

    final chips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = -1; i < filterLabels.length; i++)
          _FilterChip(
            label: i == -1 ? 'Todos' : filterLabels[i],
            selected: selectedFilter == i,
            onTap: () => onFilterChanged(i),
          ),
      ],
    );

    final actions = <Widget>[
      if (mapRoute != null)
        if (isDesktop)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 42),
              shape: const StadiumBorder(),
            ),
            onPressed: () => context.push(mapRoute!),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('Ver no mapa'),
          )
        else
          IconButton(
            icon: const Icon(Icons.map_outlined),
            onPressed: () => context.push(mapRoute!),
            tooltip: 'Ver no mapa',
          ),
      const SizedBox(width: 4),
      IconButton(
        icon: const Icon(Icons.refresh_rounded),
        onPressed: onRefresh,
        tooltip: 'Atualizar',
      ),
    ];

    Widget constrained(Widget child) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxContent),
        child: child,
      ),
    );

    final header = isDesktop
        ? Padding(
            padding: EdgeInsets.fromLTRB(hPad, 28, hPad, 0),
            child: constrained(
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Explorar',
                              style: AppTextStyles.heading1().copyWith(
                                fontSize: 28,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pets perdidos, encontrados e para adoção perto de você.',
                              style: AppTextStyles.body(
                                color: AppColors.textSecondary,
                              ).copyWith(fontSize: 15),
                            ),
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                  const SizedBox(height: 20),
                  ExploreSections(current: section),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 16),
                      SizedBox(width: 320, child: tabs),
                    ],
                  ),
                  const SizedBox(height: 14),
                  chips,
                  const SizedBox(height: 10),
                ],
              ),
            ),
          )
        : Padding(
            padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExploreSections(current: section),
                const SizedBox(height: 12),
                searchField,
                const SizedBox(height: 12),
                tabs,
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: chips,
                ),
                const SizedBox(height: 6),
              ],
            ),
          );

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              // Explorar é uma aba principal: sem botão de voltar
              automaticallyImplyLeading: false,
              title: const Text('Explorar'),
              actions: actions,
            ),
      body: Column(
        children: [
          header,
          Expanded(
            child: isDesktop
                ? Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: maxContent + hPad * 2,
                      ),
                      child: bodyBuilder(hPad),
                    ),
                  )
                : bodyBuilder(hPad),
          ),
        ],
      ),
    );
  }
}

/// Botões das seções: Perdidos, Encontrados e Adoção.
class ExploreSections extends StatelessWidget {
  final ExploreSection current;

  const ExploreSections({super.key, required this.current});

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        ExploreSection.lost,
        Icons.campaign_outlined,
        'Perdidos',
        AppRoutes.petLost,
      ),
      (
        ExploreSection.found,
        Icons.check_circle_outline,
        'Encontrados',
        AppRoutes.petFound,
      ),
      (
        ExploreSection.adoption,
        Icons.favorite_border_rounded,
        'Adoção',
        AppRoutes.petAdoption,
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: _SectionButton(
              icon: items[i].$2,
              label: items[i].$3,
              selected: items[i].$1 == current,
              onTap: items[i].$1 == current
                  ? null
                  : () => context.go(items[i].$4),
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _SectionButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.primaryDark;
    return Material(
      color: selected ? AppColors.primaryDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? AppColors.primaryDark : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Botões estreitos (celular): ícone e texto menores
            final compact = constraints.maxWidth < 150;
            return Padding(
              padding: EdgeInsets.symmetric(
                vertical: 12,
                horizontal: compact ? 4 : 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: compact ? 16 : 19, color: fg),
                  SizedBox(width: compact ? 5 : 8),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label(
                        color: fg,
                      ).copyWith(fontSize: compact ? 13 : 14),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _SegmentedTabs({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: i == index
                        ? AppColors.surfaceLight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: i == index
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: AppTextStyles.label(
                      color: i == index
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: AppTextStyles.label(
        color: selected ? Colors.white : AppColors.textPrimary,
      ),
      side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
    );
  }
}
