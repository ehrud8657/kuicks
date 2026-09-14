import 'package:flutter/material.dart';

/// 사이트 전역에서 쓰는 색상.
class AppColors {
  const AppColors._();

  static const navy = Color(0xFF071B33);
  static const crimson = Color(0xFFB31B34);
  static const crimsonSoft = Color(0xFFFBEAEC);

  // 창(모달) 머리처럼 넓은 면에 칠하는 크림슨. 원색보다 채도·명도를 낮춰 눈이 덜 부시게 한다.
  static const crimsonDeepTop = Color(0xFF9E3346);
  static const crimsonDeep = Color(0xFF872536);
  static const crimsonDeepBottom = Color(0xFF611A29);

  /// 연크림슨 바탕 위 글자·아이콘용 차분한 크림슨.
  static const crimsonMuted = Color(0xFF93303F);
  static const background = Color(0xFFF6F7F9);
  static const border = Color(0xFFE3E7EC);
  static const borderLight = Color(0xFFEAECF0);
  static const surfaceMuted = Color(0xFFF9FAFB);
  static const textBody = Color(0xFF344054);
  static const textMuted = Color(0xFF667085);
  static const textSubtle = Color(0xFF98A2B3);
  static const heroAccent = Color(0xFFEF8496);
  static const heroSubtle = Color(0xFFD0D5DD);

  // 상태 표시용
  static const success = Color(0xFF067647);
  static const successSoft = Color(0xFFE7F6EC);
  static const warning = Color(0xFFB54708);
  static const warningSoft = Color(0xFFFEF4E6);
  static const info = Color(0xFF175CD3);
  static const infoSoft = Color(0xFFEAF2FD);
  static const neutralSoft = Color(0xFFF0F2F5);
}

/// 앱 테마. 테스트에서도 같은 모양으로 그리도록 여기에 모아 둔다.
ThemeData buildAppTheme(TextTheme base) => ThemeData(
      useMaterial3: true,
      // 입력칸·버튼·날짜 선택창까지 모두 앱에 넣어 둔 한글 글꼴을 쓴다.
      fontFamily: 'Pretendard',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.crimson,
        primary: AppColors.crimson,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: base.apply(
        bodyColor: AppColors.navy,
        displayColor: AppColors.navy,
        fontFamily: 'Pretendard',
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      // 창(모달)·메뉴·날짜/시각 선택창은 흰 바탕에 그림자를 두고, 크림슨은 강조에만 쓴다.
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shadowColor: AppColors.navy.withAlpha(90),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: AppColors.navy.withAlpha(70),
        position: PopupMenuPosition.under,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: AppColors.borderLight),
        ),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textBody,
          ),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shadowColor: AppColors.navy.withAlpha(90),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        headerBackgroundColor: AppColors.crimsonDeep,
        headerForegroundColor: Colors.white,
        dividerColor: AppColors.borderLight,
        todayBorder: const BorderSide(color: AppColors.crimson),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: Colors.white,
        elevation: 24,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        dialBackgroundColor: AppColors.surfaceMuted,
        dialHandColor: AppColors.crimson,
        hourMinuteColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.crimsonSoft
              : AppColors.surfaceMuted,
        ),
        hourMinuteTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.crimson
              : AppColors.textBody,
        ),
        dayPeriodColor: AppColors.crimsonSoft,
        dayPeriodTextColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.crimson
              : AppColors.textMuted,
        ),
        dayPeriodBorderSide: const BorderSide(color: AppColors.border),
        entryModeIconColor: AppColors.textMuted,
      ),
    );

/// 상태 배지의 색 조합.
enum BadgeTone {
  neutral(AppColors.textBody, AppColors.neutralSoft),
  success(AppColors.success, AppColors.successSoft),
  warning(AppColors.warning, AppColors.warningSoft),
  danger(AppColors.crimson, AppColors.crimsonSoft),
  info(AppColors.info, AppColors.infoSoft);

  const BadgeTone(this.foreground, this.background);
  final Color foreground;
  final Color background;
}
