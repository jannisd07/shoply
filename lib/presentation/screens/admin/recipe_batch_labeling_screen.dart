import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:shoply/data/services/recipe_batch_labeling_utility.dart';
import 'package:shoply/data/services/recipe_service.dart';
import 'package:shoply/data/services/supabase_service.dart';
import 'package:shoply/core/constants/app_dimensions.dart';
import 'package:shoply/core/constants/app_text_styles.dart';

/// Admin screen for batch labeling recipes
/// Access via: Settings → About → Long press on Version
class RecipeBatchLabelingScreen extends StatefulWidget {
  const RecipeBatchLabelingScreen({super.key});

  @override
  State<RecipeBatchLabelingScreen> createState() => _RecipeBatchLabelingScreenState();
}

class _RecipeBatchLabelingScreenState extends State<RecipeBatchLabelingScreen> {
  final _utility = RecipeBatchLabelingUtility();
  final _logController = ScrollController();
  
  bool _isRunning = false;
  bool _isDryRun = true;
  bool _forceRelabel = false;
  bool _useAI = true; // 🤖 KI standardmäßig aktiviert!
  final List<String> _logs = [];
  LabelingStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void dispose() {
    _logController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _utility.getStats();
      setState(() => _stats = stats);
      _addLog('📊 Stats loaded: ${stats.totalRecipes} total, ${stats.labeledRecipes} labeled');
    } catch (e) {
      _addLog('❌ Error loading stats: $e');
    }
  }

  Future<void> _testDatabaseConnection() async {
    _addLog('');
    _addLog('🔍 Testing database connection...');
    
    try {
      final supabase = SupabaseService.instance.client;
      final currentUser = supabase.auth.currentUser;
      
      _addLog('✅ Supabase OK');
      _addLog('👤 User: ${currentUser?.id.substring(0, 8) ?? "not logged in"}');
      
      // Test direct query
      _addLog('📊 Querying recipes table directly...');
      final directResponse = await supabase
          .from('recipes')
          .select('id, name, labels')
          .limit(5);
      
      _addLog('✅ Direct query: ${(directResponse as List).length} recipes');
      
      if (directResponse.isEmpty) {
        _addLog('⚠️  Database is empty - no recipes found!');
        _addLog('💡 Create recipes in the Recipes tab first');
      } else {
        _addLog('📝 Sample recipes:');
        for (var recipe in directResponse.take(3)) {
          _addLog('   - ${recipe['name']} (labels: ${recipe['labels']?.length ?? 0})');
        }
      }
      
      // Test RecipeService
      _addLog('');
      _addLog('🔍 Testing RecipeService.getDatabaseRecipesOnly()...');
      final recipeService = RecipeService();
      final recipes = await recipeService.getDatabaseRecipesOnly();
      
      _addLog('✅ RecipeService: ${recipes.length} recipes');
      
      if (recipes.isNotEmpty) {
        _addLog('📝 First recipe: ${recipes.first.name}');
        _addLog('   - Labels: ${recipes.first.labels.isEmpty ? "empty" : recipes.first.labels.join(", ")}');
      }
      
      _addLog('');
      _addLog('✅ Database test complete!');
      
    } catch (e, stackTrace) {
      _addLog('❌ Database test error: $e');
      _addLog('📍 ${stackTrace.toString().substring(0, 200)}');
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add(message);
    });
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logController.hasClients) {
        _logController.animateTo(
          _logController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _runBatchLabeling() async {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    _addLog('🚀 Starting batch labeling...');
    _addLog('📋 Settings: DryRun=$_isDryRun, ForceRelabel=$_forceRelabel, UseAI=$_useAI');
    if (_useAI) {
      _addLog('🤖 KI-Modus aktiviert: Verwende Gemini AI für intelligente Label-Analyse');
    } else {
      _addLog('📏 Regel-Modus: Verwende regelbasierte Label-Erkennung');
    }

    try {
      final result = await _utility.labelAllRecipes(
        dryRun: _isDryRun,
        forceRelabel: _forceRelabel,
        useAI: _useAI, // 🤖 KI-Parameter übergeben
        onProgress: _addLog,
      );

      setState(() {
        _isRunning = false;
      });

      _addLog('');
      _addLog('✅ Batch labeling completed!');
      _addLog('📊 Results: ${result.processed} processed, ${result.skipped} skipped, ${result.errors} errors');

      // Reload stats
      await _loadStats();
    } catch (e, stackTrace) {
      _addLog('❌ Fatal error: $e');
      _addLog('📍 Stack trace: ${stackTrace.toString().substring(0, 200)}...');
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Batch Labeling', style: AppTextStyles.h2),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _testDatabaseConnection,
            tooltip: 'Test Database',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh Stats',
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Card
          if (_stats != null) _buildStatsCard(isDark),

          // Controls Card
          _buildControlsCard(isDark),

          // Log Section
          Expanded(child: _buildLogSection(isDark)),

          // Action Button
          _buildActionButton(theme),
        ],
      ),
    );
  }

  Widget _buildStatsCard(bool isDark) {
    return Card(
      margin: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 Current Statistics', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Total', '${_stats!.totalRecipes}', Colors.blue),
                _buildStatItem('Labeled', '${_stats!.labeledRecipes}', Colors.green),
                _buildStatItem('Unlabeled', '${_stats!.unlabeledRecipes}', Colors.orange),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _stats!.labeledPercentage / 100,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
              color: Colors.green,
            ),
            const SizedBox(height: 8),
            Text(
              '${_stats!.labeledPercentage.toStringAsFixed(1)}% labeled',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.h2.copyWith(color: color)),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }

  Widget _buildControlsCard(bool isDark) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingMedium,
        vertical: 8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚙️ Options', style: AppTextStyles.h3),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Dry Run Mode'),
              subtitle: const Text('Test without making changes to database'),
              value: _isDryRun,
              onChanged: _isRunning ? null : (value) {
                setState(() => _isDryRun = value);
              },
            ),
            SwitchListTile(
              title: const Text('Force Re-label'),
              subtitle: const Text('Re-label recipes that already have labels'),
              value: _forceRelabel,
              onChanged: _isRunning ? null : (value) {
                setState(() => _forceRelabel = value);
              },
            ),
            SwitchListTile(
              title: Row(
                children: [
                  const Text('Use AI (Gemini) '),
                  Icon(Icons.auto_awesome, size: 18, color: Colors.purple),
                ],
              ),
              subtitle: const Text('🤖 Intelligente KI-Analyse vs. 📏 Regelbasiert'),
              value: _useAI,
              onChanged: _isRunning ? null : (value) {
                setState(() => _useAI = value);
              },
            ),
            if (_useAI)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.purple),
                ),
                child: Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.purple, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'KI-Modus: Verwendet echte Gemini AI für präzise Label-Analyse',
                        style: AppTextStyles.caption.copyWith(color: Colors.purple),
                      ),
                    ),
                  ],
                ),
              ),
            if (_isDryRun)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dry run enabled - no changes will be made',
                        style: AppTextStyles.caption.copyWith(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogSection(bool isDark) {
    return Card(
      margin: const EdgeInsets.all(AppDimensions.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingMedium),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('📝 Processing Log', style: AppTextStyles.h3),
                if (_logs.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() => _logs.clear()),
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Clear'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              child: _logs.isEmpty
                  ? Center(
                      child: Text(
                        'No logs yet. Click "Start Batch Labeling" to begin.',
                        style: AppTextStyles.caption.copyWith(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      controller: _logController,
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            _logs[index],
                            style: AppTextStyles.caption.copyWith(
                              fontFamily: 'Courier',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.paddingMedium,
          AppDimensions.paddingMedium,
          AppDimensions.paddingMedium,
          AppDimensions.paddingMedium + 16, // Extra padding for bottom nav
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isRunning ? null : _runBatchLabeling,
            icon: _isRunning
                ? CupertinoActivityIndicator(radius: 10, color: Colors.white)
                : const Icon(Icons.play_arrow),
            label: Text(_isRunning ? 'Processing...' : 'Start Batch Labeling'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: _isDryRun ? Colors.orange : theme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }
}
