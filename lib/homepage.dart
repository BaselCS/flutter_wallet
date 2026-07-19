import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'financial_tracker_app/providers/transaction_provider.dart';
import 'financial_tracker_app/models/category.dart';
import 'financial_tracker_app/utils/theme.dart';
import 'financial_tracker_app/services/csv_export_service.dart';
import 'package:file_picker/file_picker.dart';
import 'financial_tracker_app/widgets/popup_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> appMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => TransactionProvider())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: appMessengerKey,
        // ضبط اتجاه النص ليكون من اليمين لليسار
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFFF6F4EF),
          fontFamily: 'Tajawal', // يفضل استخدام خط عربي مثل تجوال
        ),
        home: HomePage(),
      ),
    );
  }
}

// --- واجهة المستخدم الرئيسية ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TransactionProvider>().init();
      _checkFirstLaunch();
    });
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    if (isFirstLaunch) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.surfaceColor,
          title: const Text('مساعدة'),
          content: const Text("""
السلام عليكم حياك الله
عند لمسك على اسم الشهر لمرة ستذهب لشهر الحاليe
و عند لمسك إيه مرتين ستظهر لك نافذة مساعدة
 """),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسناً'),
            ),
          ],
        ),
      );
      await prefs.setBool('is_first_launch', false);
    }
  }

  Future<void> _importDataCsv() async {
    // 1. قراءة المزود قبل عملية الانتظار لتجنب خطأ سياق البناء
    final provider = context.read<TransactionProvider>();

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;

        final count = await provider.importFromCsv(path);

        final messenger = appMessengerKey.currentState;

        // 2. استخدام كتلة برمجية لجملة الشرط
        if (messenger == null) {
          return;
        }

        messenger.showSnackBar(
          SnackBar(content: Text('تم استيراد $count عملية بنجاح')),
        );
      }
    } catch (e) {
      final messenger = appMessengerKey.currentState;

      if (messenger == null) {
        return;
      }

      // عرض نص الاستثناء الفعلي للمساعدة في تصحيح الأخطاء
      messenger.showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء الاستيراد: ${e.toString()}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _showAllTransactionsHistory() async {
    final provider = context.read<TransactionProvider>();
    final txns = await provider.getAllTransactions();

    final navigatorContext = appNavigatorKey.currentContext;
    if (navigatorContext == null) return;

    showDialog<void>(
      // ignore: use_build_context_synchronously
      context: navigatorContext,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('سجل العمليات'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: txns.isEmpty
              ? const Center(child: Text('لا توجد بيانات حتى الآن.'))
              : ListView.separated(
                  itemCount: txns.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (c, i) {
                    final t = txns[i];
                    return ListTile(
                      dense: true,
                      title: Text('${t.categoryName} - ${t.amount} ر.س'),
                      subtitle: Text(
                        'الشهر: ${t.hijriMonth} • ${DateTime.fromMillisecondsSinceEpoch(t.createdAt)}',
                      ),
                      trailing: Icon(
                        t.isIncome ? Icons.trending_up : Icons.trending_down,
                        color: t.isIncome
                            ? AppTheme.primaryColor
                            : AppTheme.accentColor,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(navigatorContext).pop(),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  // Future<void> _generateFakeDataForLastSixMonths() async {
  //   await context
  //       .read<TransactionProvider>()
  //       .generateFakeDataForLastSixMonths();

  //   final messenger = appMessengerKey.currentState;
  //   if (messenger == null) return;

  //   messenger.showSnackBar(
  //     const SnackBar(content: Text('ولدت بيانات وهمية لآخر 6 أشهر')),
  //   );
  // }

  Future<void> _confirmAndDeleteAllData() async {
    final navigatorContext = appNavigatorKey.currentContext;
    if (navigatorContext == null) return;

    final confirmed = await showDialog<bool>(
      context: navigatorContext,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('حذف البيانات'),
        content: const Text('هل تريد حذف البيانات المخزنة نهائيًا؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(navigatorContext).pop(false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(navigatorContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
            ),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<TransactionProvider>().deleteAllData();

    final messenger = appMessengerKey.currentState;
    if (messenger == null) return;

    messenger.showSnackBar(const SnackBar(content: Text('حُذفت البيانات')));
  }

  Future<void> _confirmAndDeleteCategory(CategoryModel category) async {
    final navigatorContext = appNavigatorKey.currentContext;
    if (navigatorContext == null) return;

    final confirmed = await showDialog<bool>(
      context: navigatorContext,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('حذف الفئة'),
        content: Text('هل تريد حذف فئة "${category.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(navigatorContext).pop(false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(navigatorContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentColor,
            ),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<TransactionProvider>().deleteCategory(category);

    final messenger = appMessengerKey.currentState;
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(content: Text('حُذفت الفئة: ${category.name}')),
    );
  }

  Future<void> _showSettingsPopup() async {
    final navigatorContext = appNavigatorKey.currentContext;
    if (navigatorContext == null) return;

    showDialog<void>(
      context: navigatorContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: const Text('الإعدادات'),
        contentPadding: const EdgeInsets.only(top: 8),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('عرض السجل'),
              onTap: () async {
                Navigator.of(dialogContext).pop();
                await _showAllTransactionsHistory();
              },
            ),
            // ListTile(
            //   leading: const Icon(Icons.file_upload),
            //   title: const Text('تصدير البيانات (CSV)'),
            //   onTap: () async {
            //     Navigator.of(dialogContext).pop();
            //     await _exportCurrentMonthCsv();
            //   },
            // ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('استيراد بيانات (CSV)'),
              onTap: () async {
                Navigator.of(dialogContext).pop();
                await _importDataCsv();
              },
            ),
            const Divider(),
            // ListTile(
            //   leading: const Icon(Icons.auto_awesome),
            //   title: const Text('توليد بيانات وهمية لآخر 6 أشهر'),
            //   onTap: () async {
            //     Navigator.of(dialogContext).pop();
            //     await _generateFakeDataForLastSixMonths();
            //   },
            // ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'حذف البيانات',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                Navigator.of(dialogContext).pop();
                await _confirmAndDeleteAllData();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportCurrentMonthCsv() async {
    final path = await CsvExportService.exportAll();

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'text/csv')],
          subject: 'مشاركة ميزانيتي',
          text: 'ميزانيتي',
        ),
      );
    } on MissingPluginException {
      final messenger = appMessengerKey.currentState;
      if (messenger == null) return;

      messenger.showSnackBar(
        SnackBar(content: Text('حُفظ الملف، لكن المشاركة غير متاحة: $path')),
      );
    }
  }

  Future<void> _endCurrentMonth() async {
    await context.read<TransactionProvider>().endMonth();

    final messenger = appMessengerKey.currentState;
    if (messenger == null) return;

    messenger.showSnackBar(const SnackBar(content: Text('انتهى الشهر')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgColor,
      body: Column(
        children: [
          _buildCustomAppBar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSummaryCard(context),
                  const SizedBox(height: 16),
                  _buildInputCard(context),
                  const SizedBox(height: 16),
                  _buildCategoriesCard(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. الشريط العلوي
  Widget _buildCustomAppBar(BuildContext context) {
    final provider = context.watch<TransactionProvider>();

    return Container(
      color: AppTheme.primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: provider.goToPreviousMonth,
              ),
              GestureDetector(
                onTap: provider.goToCurrentMonth,
                onDoubleTap: _showSettingsPopup,
                child: Text(
                  provider.viewedMonthTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  color: provider.canGoToNextMonth
                      ? Colors.white
                      : Colors.white38,
                  size: 20,
                ),
                onPressed: provider.canGoToNextMonth
                    ? provider.goToNextMonth
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: OutlinedButton.icon(
                  onPressed: _exportCurrentMonthCsv,
                  icon: const Icon(Icons.share, color: Colors.white, size: 18),
                  label: const Text(
                    'مشاركة الميزانية',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white54),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: ElevatedButton.icon(
                  onPressed: _endCurrentMonth,
                  icon: const Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'إنهاء الشهر',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. بطاقة الخلاصة
  Widget _buildSummaryCard(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);
    final Color balanceColor = provider.totalIncome >= provider.totalExpenses
        ? AppTheme.primaryColor
        : AppTheme.accentColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.highlightColor, // لون خلفية التمييز
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text('ثروتي', style: TextStyle(color: Colors.black54)),
                Text(
                  '${provider.actualBalance} ر.س',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: balanceColor,
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('المدخولات', '${provider.totalIncome}'),
              _buildSummaryItem(
                'المصروفات',
                '${provider.totalExpenses}',
                isExpense: true,
              ),
              _buildSummaryItem('المدخرات', '${provider.previousBalance}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String title,
    String value, {
    bool isExpense = false,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isExpense ? AppTheme.accentColor : AppTheme.primaryColor,
          ),
        ),
      ],
    );
  }

  // 3. بطاقة إدخال المبلغ
  Widget _buildInputCard(BuildContext context) {
    final provider = Provider.of<TransactionProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Column(
        children: [
          const Text('المبلغ', style: TextStyle(color: Colors.black54)),
          Text(
            '${provider.currentAmount.toInt()} ر.س',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'حذف (-)',
                style: TextStyle(color: AppTheme.accentColor),
              ),
              Switch(
                value: provider.isAddition,
                activeThumbColor: AppTheme.primaryColor,
                inactiveThumbColor: AppTheme.accentColor,
                onChanged: (value) => provider.toggleInputType(value),
              ),
              Text(
                'إضافة (+)',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: provider.quickAmounts.length,
            itemBuilder: (context, index) {
              final amount = provider.quickAmounts[index];
              return ElevatedButton(
                onPressed: () => provider.addAmount(amount),
                style: ElevatedButton.styleFrom(
                  backgroundColor: provider.isAddition
                      ? AppTheme.primaryColor
                      : AppTheme.accentColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '$amount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: provider.clearAmount,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondarySurface,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              child: const Text(
                'تصفير',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 4. بطاقة الفئات
  Widget _buildCategoriesCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outlineColor),
      ),
      child: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text('الفئات', style: TextStyle(color: Colors.black54)),
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: provider.categories.length + 1,
                itemBuilder: (context, index) {
                  // زر إضافة فئة جديدة
                  if (index == provider.categories.length) {
                    return InkWell(
                      onTap: () async {
                        final result = await showDialog<Map<String, dynamic>>(
                          context: context,
                          builder: (_) => const AddCategoryDialog(),
                        );

                        if (result != null) {
                          await provider.addCategory(
                            result['name'] as String,
                            result['icon'] as String,
                            result['isIncome'] as bool,
                          );
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade400,
                            width: 1.5,
                          ),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, color: Colors.black54),
                            SizedBox(height: 4),
                            Text(
                              'إضافة فئة',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // عرض الفئات الموجودة
                  final category = provider.categories[index];

                  // استخدام CategoryModel كنوع للبيانات بدلاً من المؤشر الثابت
                  return DragTarget<CategoryModel>(
                    // التبديل الفوري عند التمرير فوق عنصر آخر
                    onWillAcceptWithDetails: (details) {
                      final draggedCategory = details.data;

                      // جلب المؤشر المباشر الحالي للعنصر المسحوب
                      final oldIndex = provider.categories.indexOf(
                        draggedCategory,
                      );

                      if (oldIndex != index && oldIndex != -1) {
                        provider.reorderCategories(oldIndex, index);
                      }
                      return true;
                    },
                    builder: (context, candidateData, rejectedData) {
                      return LongPressDraggable<CategoryModel>(
                        data: category,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Opacity(
                            opacity: 0.8,
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width / 4,
                              height: MediaQuery.of(context).size.width / 4,
                              child: _buildCategoryItem(
                                category,
                                provider,
                                context,
                              ),
                            ),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.3,
                          child: _buildCategoryItem(
                            category,
                            provider,
                            context,
                          ),
                        ),
                        child: _buildCategoryItem(category, provider, context),
                      );
                    },
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // أداة فرعية لبناء شكل بطاقة الفئة مع زر التعديل
  Widget _buildCategoryItem(
    CategoryModel category,
    TransactionProvider provider,
    BuildContext context,
  ) {
    return Stack(
      children: [
        InkWell(
          onTap: () => provider.saveTransaction(category.name),
          onDoubleTap: () =>
              _showEditCategoryOptions(context, category, provider),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: category.isIncome
                    ? AppTheme.primaryColor
                    : AppTheme.accentColor,
                width: category.isIncome ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.circleBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      category.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: category.isIncome
                        ? AppTheme.primaryColor
                        : AppTheme.accentColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // نافذة سفلية تعرض خيارات التعديل والحذف
  Future<void> _showEditCategoryOptions(
    BuildContext context,
    CategoryModel category,
    TransactionProvider provider,
  ) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('تعديل الفئة'),
                onTap: () async {
                  Navigator.pop(ctx);
                  // نستخدم نفس نافذة الإضافة المسبقة كنموذج (يفضل إنشاء نسخة منها للتعديل لاحقاً وتمرير البيانات الحالية لها)
                  final result = await showDialog<Map<String, dynamic>>(
                    context: context,
                    builder: (_) =>
                        const AddCategoryDialog(), // يمكنك لاحقاً تحويلها لـ EditCategoryDialog وتمرير بيانات الفئة لها
                  );

                  if (result != null) {
                    await provider.updateCategory(
                      category,
                      result['name'] as String,
                      result['icon'] as String,
                      result['isIncome'] as bool,
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'حذف الفئة',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmAndDeleteCategory(category);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
