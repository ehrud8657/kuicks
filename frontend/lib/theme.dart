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

/// 버튼 공통 모서리. 알약·크게 둥근 모양 대신 단정한 8.
const _buttonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(8)),
);

/// 앱 테마. 테스트에서도 같은 모양으로 그리도록 여기에 모아 둔다.
ThemeData buildAppTheme(TextTheme base) => ThemeData(
      useMaterial3: true,
      // 입력칸·버튼·날짜 선택창까지 모두 앱에 넣어 둔 한글 글꼴을 쓴다.
      fontFamily: 'Pretendard',
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.crimson,
        primary: AppColors.crimson,
      ),
      // 실제 바탕은 AppBackdrop 그라데이션이 칠한다. 로딩 중에도 튀지 않게 가운데 색으로 둔다.
      scaffoldBackgroundColor: const Color(0xFFF5F5F4),
      dividerColor: AppColors.borderLight,
      textTheme: base.apply(
        bodyColor: AppColors.navy,
        displayColor: AppColors.navy,
        fontFamily: 'Pretendard',
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        // 떠 있는 그림자 대신 바닥에 붙은 가까운 그림자와 선명한 테두리로 구분한다.
        elevation: 1,
        shadowColor: Color(0x1F071B33),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      filledButtonTheme: const FilledButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(_buttonShape),
          padding: WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          textStyle: WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          elevation: WidgetStatePropertyAll(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(_buttonShape),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.textSubtle
                : AppColors.crimson,
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.hovered)
                ? AppColors.surfaceMuted
                : Colors.white,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.disabled)
                  ? AppColors.borderLight
                  : states.contains(WidgetState.hovered)
                      ? AppColors.crimson.withAlpha(90)
                      : AppColors.border,
            ),
          ),
          overlayColor: WidgetStatePropertyAll(AppColors.crimson.withAlpha(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(
              fontFamily: 'Pretendard',
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          overlayColor: WidgetStatePropertyAll(AppColors.crimson.withAlpha(14)),
        ),
      ),
      // 학기·게시판 분류 칩: 체크 표시 없는 알약, 고르면 크림슨으로 채운다.
      chipTheme: ChipThemeData(
        showCheckmark: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        pressElevation: 0,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.crimson
              : states.contains(WidgetState.hovered)
                  ? AppColors.surfaceMuted
                  : Colors.white,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? AppColors.crimson
                : AppColors.border,
          ),
        ),
        // 상태별 글자 모양(WidgetStateTextStyle)을 쓰면 칩이 그 객체를 그대로 글자 모양으로 써서
        // 테마 글꼴이 빠지고 한글 대체 글꼴을 받아온다. 일반 글자 모양 + 선택 시 secondaryLabelStyle로 둔다.
        labelStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textBody,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppColors.crimson,
        collapsedIconColor: AppColors.textMuted,
        textColor: AppColors.crimson,
        collapsedTextColor: AppColors.navy,
        shape: Border(),
        collapsedShape: Border(),
      ),
      inputDecorationTheme: const InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppColors.crimson, width: 1.4),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        elevation: 6,
        actionTextColor: AppColors.heroAccent,
        contentTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: Colors.white,
          fontSize: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.crimson,
        linearTrackColor: AppColors.crimsonSoft,
      ),
      // 구분선은 기본(연분홍 기운) 대신 옅은 회색.
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
      ),
      // 출석 상태 선택(출석·지각·결석·공결): 짙은 기본 테두리 대신 옅은 테두리와 둥근 모서리.
      segmentedButtonTheme: const SegmentedButtonThemeData(
        style: ButtonStyle(
          side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: AppColors.borderLight,
        overlayColor: WidgetStatePropertyAll(AppColors.crimson.withAlpha(12)),
      ),
      // 창(모달)·메뉴·날짜/시각 선택창은 흰 바탕에 그림자를 두고, 크림슨은 강조에만 쓴다.
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 24,
        shadowColor: AppColors.navy.withAlpha(90),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 10,
        shadowColor: AppColors.navy.withAlpha(70),
        position: PopupMenuPosition.under,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
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
          borderRadius: BorderRadius.all(Radius.circular(14)),
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
          borderRadius: BorderRadius.all(Radius.circular(14)),
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
