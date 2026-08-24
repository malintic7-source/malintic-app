import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_formations/utils/responsive.dart';

/// Pumps a widget sized to [size] and returns the [Responsive] helper plus the
/// [BuildContext] it was built from.
Future<({Responsive r, BuildContext context})> buildResponsive(
  WidgetTester tester,
  Size size,
) async {
  late BuildContext capturedContext;
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: Builder(
        builder: (context) {
          capturedContext = context;
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return (r: Responsive(capturedContext), context: capturedContext);
}

void main() {
  const mobile = Size(400, 800);
  const smallTablet = Size(700, 1000);
  const tablet = Size(900, 1200);
  const desktop = Size(1400, 900);

  group('breakpoints', () {
    testWidgets('classifies a mobile width', (tester) async {
      final (r: r, context: _) = await buildResponsive(tester, mobile);

      expect(r.isMobile, isTrue);
      expect(r.isSmallTablet, isFalse);
      expect(r.isTablet, isFalse);
      expect(r.isDesktop, isFalse);
      expect(r.isMobileOrSmall, isTrue);
      expect(r.screenWidth, 400);
      expect(r.screenHeight, 800);
    });

    testWidgets('classifies a small tablet width', (tester) async {
      final (r: r, context: _) = await buildResponsive(tester, smallTablet);

      expect(r.isMobile, isFalse);
      expect(r.isSmallTablet, isTrue);
      expect(r.isTablet, isFalse);
      expect(r.isDesktop, isFalse);
      expect(r.isMobileOrSmall, isTrue);
    });

    testWidgets('classifies a tablet width', (tester) async {
      final (r: r, context: _) = await buildResponsive(tester, tablet);

      expect(r.isSmallTablet, isFalse);
      expect(r.isTablet, isTrue);
      expect(r.isDesktop, isFalse);
      expect(r.isMobileOrSmall, isFalse);
    });

    testWidgets('classifies a desktop width', (tester) async {
      final (r: r, context: _) = await buildResponsive(tester, desktop);

      expect(r.isMobile, isFalse);
      expect(r.isTablet, isFalse);
      expect(r.isDesktop, isTrue);
      expect(r.isMobileOrSmall, isFalse);
    });
  });

  group('layout metrics', () {
    testWidgets('scales paddings with the breakpoint', (tester) async {
      final (r: mobileR, context: _) = await buildResponsive(tester, mobile);
      expect(mobileR.contentPadding,
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10));
      expect(mobileR.horizontalPadding,
          const EdgeInsets.symmetric(horizontal: 12));

      final (r: tabletR, context: _) = await buildResponsive(tester, tablet);
      expect(tabletR.contentPadding,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14));
      expect(tabletR.horizontalPadding,
          const EdgeInsets.symmetric(horizontal: 16));

      final (r: desktopR, context: _) = await buildResponsive(tester, desktop);
      expect(desktopR.contentPadding,
          const EdgeInsets.symmetric(horizontal: 24, vertical: 16));
      expect(desktopR.horizontalPadding,
          const EdgeInsets.symmetric(horizontal: 24));
    });

    testWidgets('scales the column counts with the breakpoint', (tester) async {
      final (r: mobileR, context: _) = await buildResponsive(tester, mobile);
      expect(mobileR.gridColumns, 1);
      expect(mobileR.statColumns, 2);
      expect(mobileR.actionColumns, 2);
      expect(mobileR.summaryColumns, 1);

      final (r: smallTabletR, context: _) =
          await buildResponsive(tester, smallTablet);
      expect(smallTabletR.gridColumns, 2);

      final (r: tabletR, context: _) = await buildResponsive(tester, tablet);
      expect(tabletR.gridColumns, 2);
      expect(tabletR.statColumns, 3);
      expect(tabletR.actionColumns, 4);
      expect(tabletR.summaryColumns, 2);

      final (r: desktopR, context: _) = await buildResponsive(tester, desktop);
      expect(desktopR.gridColumns, 3);
      expect(desktopR.statColumns, 4);
      expect(desktopR.summaryColumns, 3);
    });

    testWidgets('scales the typography and card metrics', (tester) async {
      final (r: mobileR, context: _) = await buildResponsive(tester, mobile);
      expect(mobileR.headingFontSize, 16);
      expect(mobileR.subheadingFontSize, 13);
      expect(mobileR.bodyFontSize, 12);
      expect(mobileR.captionFontSize, 11);
      expect(mobileR.cardBorderRadius, 14);
      expect(mobileR.sectionSpacing, 12);
      expect(mobileR.cardSpacing, 8);
      expect(mobileR.statAspectRatio, 1.35);

      final (r: tabletR, context: _) = await buildResponsive(tester, tablet);
      expect(tabletR.headingFontSize, 19);
      expect(tabletR.subheadingFontSize, 14);
      expect(tabletR.statAspectRatio, 1.6);

      final (r: desktopR, context: _) = await buildResponsive(tester, desktop);
      expect(desktopR.headingFontSize, 22);
      expect(desktopR.subheadingFontSize, 15);
      expect(desktopR.bodyFontSize, 13);
      expect(desktopR.captionFontSize, 12);
      expect(desktopR.cardBorderRadius, 18);
      expect(desktopR.sectionSpacing, 20);
      expect(desktopR.cardSpacing, 12);
      expect(desktopR.statAspectRatio, 1.8);
    });

    testWidgets('sizes dialogs relative to the screen on mobile', (tester) async {
      final (r: mobileR, context: _) = await buildResponsive(tester, mobile);
      expect(mobileR.dialogMaxWidth, mobile.width - 24);
      expect(mobileR.dialogMaxHeight, closeTo(mobile.height * 0.88, 0.001));
      expect(mobileR.formMaxWidth, mobile.width - 32);

      final (r: tabletR, context: _) = await buildResponsive(tester, tablet);
      expect(tabletR.dialogMaxWidth, 540);
      expect(tabletR.dialogMaxHeight, closeTo(tablet.height * 0.82, 0.001));
      expect(tabletR.formMaxWidth, 420);

      final (r: desktopR, context: _) = await buildResponsive(tester, desktop);
      expect(desktopR.dialogMaxWidth, 600);
      expect(desktopR.maxContentWidth, 1280);
    });

    testWidgets('scales charts and icons', (tester) async {
      final (r: mobileR, context: _) = await buildResponsive(tester, mobile);
      expect(mobileR.chartHeight, 130);
      expect(mobileR.miniChartSize, 80);
      expect(mobileR.iconSize, 18);
      expect(mobileR.largeIconSize, 24);

      final (r: tabletR, context: _) = await buildResponsive(tester, tablet);
      expect(tabletR.chartHeight, 150);

      final (r: desktopR, context: _) = await buildResponsive(tester, desktop);
      expect(desktopR.chartHeight, 170);
      expect(desktopR.miniChartSize, 100);
      expect(desktopR.iconSize, 20);
      expect(desktopR.largeIconSize, 28);
    });

    testWidgets('hides data tables on mobile and small tablets', (tester) async {
      final (r: mobileR, context: _) = await buildResponsive(tester, mobile);
      final (r: smallTabletR, context: _) =
          await buildResponsive(tester, smallTablet);
      final (r: desktopR, context: _) = await buildResponsive(tester, desktop);

      expect(mobileR.showDataTable, isFalse);
      expect(smallTabletR.showDataTable, isFalse);
      expect(desktopR.showDataTable, isTrue);
    });
  });

  group('responsive<T>', () {
    testWidgets('returns the value matching the breakpoint', (tester) async {
      final (r: mobileR, context: _) = await buildResponsive(tester, mobile);
      final (r: tabletR, context: _) = await buildResponsive(tester, tablet);
      final (r: desktopR, context: _) = await buildResponsive(tester, desktop);

      expect(
        mobileR.responsive(mobile: 'm', tablet: 't', desktop: 'd'),
        'm',
      );
      expect(
        tabletR.responsive(mobile: 'm', tablet: 't', desktop: 'd'),
        't',
      );
      expect(
        desktopR.responsive(mobile: 'm', tablet: 't', desktop: 'd'),
        'd',
      );
    });

    testWidgets('falls back to the desktop value when tablet is omitted',
        (tester) async {
      final (r: tabletR, context: _) = await buildResponsive(tester, tablet);
      final (r: smallTabletR, context: _) =
          await buildResponsive(tester, smallTablet);

      expect(tabletR.responsive(mobile: 'm', desktop: 'd'), 'd');
      expect(smallTabletR.responsive(mobile: 'm', tablet: 't', desktop: 'd'), 'd');
    });
  });

  group('ResponsiveContext extension', () {
    testWidgets('exposes the helper and the screen predicates', (tester) async {
      final (r: _, context: mobileContext) =
          await buildResponsive(tester, mobile);
      expect(mobileContext.r.isMobile, isTrue);
      expect(mobileContext.isMobileScreen, isTrue);
      expect(mobileContext.isTabletScreen, isFalse);
      expect(mobileContext.isDesktopScreen, isFalse);

      final (r: _, context: tabletContext) =
          await buildResponsive(tester, tablet);
      expect(tabletContext.isMobileScreen, isFalse);
      expect(tabletContext.isTabletScreen, isTrue);
      expect(tabletContext.isDesktopScreen, isFalse);

      final (r: _, context: desktopContext) =
          await buildResponsive(tester, desktop);
      expect(desktopContext.isMobileScreen, isFalse);
      expect(desktopContext.isTabletScreen, isFalse);
      expect(desktopContext.isDesktopScreen, isTrue);
    });
  });
}
