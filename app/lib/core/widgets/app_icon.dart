import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_style.dart';

/// An [Icon] that draws in the style's own icon set: Material's symbols in
/// the nemo and Material styles, and in the macOS style their nearest
/// Phosphor glyph, whose thin even strokes read as SF Symbols do -- which
/// themselves may only ship in apps on Apple's platforms.
///
/// Takes a Material icon, so every call site names one set; an icon with no
/// counterpart here stays Material's.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    this.size,
    this.color,
    this.semanticLabel,
    super.key,
  });

  final IconData? icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Icon(
    context.styleIcon(icon),
    size: size,
    color: color,
    semanticLabel: semanticLabel,
  );
}

extension StyleIcons on BuildContext {
  /// [icon] as this style draws it.
  IconData? styleIcon(IconData? icon) =>
      appStyle == AppStyle.macos ? _phosphor(icon) ?? icon : icon;
}

/// Material's symbols as the macOS style draws them, or null for one with
/// no counterpart: Phosphor's glyphs, named in the comments. Filled where
/// Apple fills its own: the selected destination, a flag, a pin, a trophy.
///
/// Constants throughout, so a web build keeps only the glyphs named here;
/// the fonts are subset to them already. Mapping another means running
/// tool/subset_phosphor.sh; app_icon_font_test.dart fails until then.
IconData? _phosphor(IconData? icon) => switch (icon) {
  Icons.delete_outline_rounded => const IconData(
    0xe4a6,
    fontFamily: 'PhosphorRegular',
  ), // trash
  Icons.wb_sunny_outlined => const IconData(
    0xe472,
    fontFamily: 'PhosphorRegular',
  ), // sun
  Icons.flag_rounded => const IconData(
    0xe244,
    fontFamily: 'PhosphorFill',
  ), // flag
  Icons.close_rounded => const IconData(
    0xe4f6,
    fontFamily: 'PhosphorRegular',
  ), // x
  Icons.check_rounded => const IconData(
    0xe182,
    fontFamily: 'PhosphorRegular',
  ), // check
  Icons.add_rounded => const IconData(
    0xe3d4,
    fontFamily: 'PhosphorRegular',
  ), // plus
  Icons.task_alt => const IconData(
    0xe184,
    fontFamily: 'PhosphorRegular',
  ), // checkCircle
  Icons.settings_outlined => const IconData(
    0xe270,
    fontFamily: 'PhosphorRegular',
  ), // gear
  Icons.search_rounded => const IconData(
    0xe30c,
    fontFamily: 'PhosphorRegular',
  ), // magnifyingGlass
  Icons.schedule_rounded => const IconData(
    0xe19a,
    fontFamily: 'PhosphorRegular',
  ), // clock
  Icons.repeat_rounded => const IconData(
    0xe3f6,
    fontFamily: 'PhosphorRegular',
  ), // repeat
  Icons.push_pin => const IconData(
    0xe3e2,
    fontFamily: 'PhosphorFill',
  ), // pushPin
  Icons.people_outline_rounded => const IconData(
    0xe4d6,
    fontFamily: 'PhosphorRegular',
  ), // users
  Icons.open_in_new => const IconData(
    0xe5de,
    fontFamily: 'PhosphorRegular',
  ), // arrowSquareOut
  Icons.add_task => const IconData(
    0xe3d6,
    fontFamily: 'PhosphorRegular',
  ), // plusCircle
  Icons.warning_amber_rounded => const IconData(
    0xe4e0,
    fontFamily: 'PhosphorRegular',
  ), // warning
  Icons.undo_rounded => const IconData(
    0xe038,
    fontFamily: 'PhosphorRegular',
  ), // arrowCounterClockwise
  Icons.tag_rounded => const IconData(
    0xe2a2,
    fontFamily: 'PhosphorRegular',
  ), // hash
  Icons.system_update_alt_rounded => const IconData(
    0xe20c,
    fontFamily: 'PhosphorRegular',
  ), // downloadSimple
  Icons.sticky_note_2_outlined => const IconData(
    0xe348,
    fontFamily: 'PhosphorRegular',
  ), // note
  Icons.person_remove_outlined => const IconData(
    0xe4ce,
    fontFamily: 'PhosphorRegular',
  ), // userMinus
  Icons.list_alt_rounded => const IconData(
    0xe2f2,
    fontFamily: 'PhosphorRegular',
  ), // listBullets
  Icons.folder_outlined => const IconData(
    0xe24a,
    fontFamily: 'PhosphorRegular',
  ), // folder
  Icons.event_outlined => const IconData(
    0xe108,
    fontFamily: 'PhosphorRegular',
  ), // calendar
  Icons.event_available_outlined => const IconData(
    0xe712,
    fontFamily: 'PhosphorRegular',
  ), // calendarCheck
  Icons.edit_outlined => const IconData(
    0xe3b4,
    fontFamily: 'PhosphorRegular',
  ), // pencilSimple
  Icons.cloud_off_rounded => const IconData(
    0xe1b6,
    fontFamily: 'PhosphorRegular',
  ), // cloudSlash
  Icons.cloud_off_outlined => const IconData(
    0xe1b6,
    fontFamily: 'PhosphorRegular',
  ), // cloudSlash
  Icons.chevron_right_rounded => const IconData(
    0xe13a,
    fontFamily: 'PhosphorRegular',
  ), // caretRight
  Icons.checklist_rounded => const IconData(
    0xeadc,
    fontFamily: 'PhosphorRegular',
  ), // listChecks
  Icons.workspace_premium_outlined => const IconData(
    0xe320,
    fontFamily: 'PhosphorRegular',
  ), // medal
  Icons.work_outline_rounded => const IconData(
    0xe0ee,
    fontFamily: 'PhosphorRegular',
  ), // briefcase
  Icons.whatshot_outlined => const IconData(
    0xe242,
    fontFamily: 'PhosphorRegular',
  ), // fire
  Icons.water_drop_outlined => const IconData(
    0xe210,
    fontFamily: 'PhosphorRegular',
  ), // drop
  Icons.volume_up_outlined => const IconData(
    0xe44a,
    fontFamily: 'PhosphorRegular',
  ), // speakerHigh
  Icons.visibility_outlined => const IconData(
    0xe220,
    fontFamily: 'PhosphorRegular',
  ), // eye
  Icons.unfold_more_rounded => const IconData(
    0xe140,
    fontFamily: 'PhosphorRegular',
  ), // caretUpDown
  Icons.undo => const IconData(
    0xe038,
    fontFamily: 'PhosphorRegular',
  ), // arrowCounterClockwise
  Icons.tune_rounded => const IconData(
    0xe434,
    fontFamily: 'PhosphorRegular',
  ), // slidersHorizontal
  Icons.trending_up_rounded => const IconData(
    0xe4ae,
    fontFamily: 'PhosphorRegular',
  ), // trendUp
  Icons.today_rounded => const IconData(
    0xe7b2,
    fontFamily: 'PhosphorFill',
  ), // calendarDot
  Icons.today_outlined => const IconData(
    0xe7b2,
    fontFamily: 'PhosphorRegular',
  ), // calendarDot
  Icons.today => const IconData(
    0xe7b2,
    fontFamily: 'PhosphorFill',
  ), // calendarDot
  Icons.title => const IconData(0xe48a, fontFamily: 'PhosphorRegular'), // textT
  Icons.sync_rounded => const IconData(
    0xe094,
    fontFamily: 'PhosphorRegular',
  ), // arrowsClockwise
  Icons.subdirectory_arrow_right => const IconData(
    0xe046,
    fontFamily: 'PhosphorRegular',
  ), // arrowElbowDownRight
  Icons.sticky_note_2 => const IconData(
    0xe348,
    fontFamily: 'PhosphorFill',
  ), // note
  Icons.star_outline_rounded => const IconData(
    0xe46a,
    fontFamily: 'PhosphorRegular',
  ), // star
  Icons.splitscreen_outlined => const IconData(
    0xe874,
    fontFamily: 'PhosphorRegular',
  ), // squareSplitVertical
  Icons.sort_rounded => const IconData(
    0xe098,
    fontFamily: 'PhosphorRegular',
  ), // arrowsDownUp
  Icons.shopping_cart_outlined => const IconData(
    0xe41e,
    fontFamily: 'PhosphorRegular',
  ), // shoppingCart
  Icons.search_outlined => const IconData(
    0xe30c,
    fontFamily: 'PhosphorRegular',
  ), // magnifyingGlass
  Icons.search_off_rounded => const IconData(
    0xe30e,
    fontFamily: 'PhosphorRegular',
  ), // magnifyingGlassMinus
  Icons.search => const IconData(
    0xe30c,
    fontFamily: 'PhosphorFill',
  ), // magnifyingGlass
  Icons.school_outlined => const IconData(
    0xe62c,
    fontFamily: 'PhosphorRegular',
  ), // graduationCap
  Icons.rocket_launch_outlined => const IconData(
    0xe3fe,
    fontFamily: 'PhosphorRegular',
  ), // rocketLaunch
  Icons.remove_circle_outline => const IconData(
    0xe32c,
    fontFamily: 'PhosphorRegular',
  ), // minusCircle
  Icons.refresh_rounded => const IconData(
    0xe036,
    fontFamily: 'PhosphorRegular',
  ), // arrowClockwise
  Icons.redo => const IconData(
    0xe036,
    fontFamily: 'PhosphorRegular',
  ), // arrowClockwise
  Icons.push_pin_outlined => const IconData(
    0xe3e2,
    fontFamily: 'PhosphorRegular',
  ), // pushPin
  Icons.photo_library_outlined => const IconData(
    0xe836,
    fontFamily: 'PhosphorRegular',
  ), // images
  Icons.photo_camera_outlined => const IconData(
    0xe10e,
    fontFamily: 'PhosphorRegular',
  ), // camera
  Icons.person_outline => const IconData(
    0xe4c2,
    fontFamily: 'PhosphorRegular',
  ), // user
  Icons.person_add_outlined => const IconData(
    0xe4d0,
    fontFamily: 'PhosphorRegular',
  ), // userPlus
  Icons.payments_outlined => const IconData(
    0xe588,
    fontFamily: 'PhosphorRegular',
  ), // money
  Icons.password_rounded => const IconData(
    0xe752,
    fontFamily: 'PhosphorRegular',
  ), // password
  Icons.open_in_new_rounded => const IconData(
    0xe5de,
    fontFamily: 'PhosphorRegular',
  ), // arrowSquareOut
  Icons.notifications_outlined => const IconData(
    0xe0ce,
    fontFamily: 'PhosphorRegular',
  ), // bell
  Icons.notes_rounded => const IconData(
    0xe484,
    fontFamily: 'PhosphorRegular',
  ), // textAlignLeft
  Icons.military_tech_outlined => const IconData(
    0xecfc,
    fontFamily: 'PhosphorRegular',
  ), // medalMilitary
  Icons.menu_book_outlined => const IconData(
    0xe0e6,
    fontFamily: 'PhosphorRegular',
  ), // bookOpen
  Icons.logout_rounded => const IconData(
    0xe42a,
    fontFamily: 'PhosphorRegular',
  ), // signOut
  Icons.lock_outline => const IconData(
    0xe2fa,
    fontFamily: 'PhosphorRegular',
  ), // lock
  Icons.local_fire_department_rounded => const IconData(
    0xe624,
    fontFamily: 'PhosphorFill',
  ), // flame
  Icons.local_fire_department_outlined => const IconData(
    0xe624,
    fontFamily: 'PhosphorRegular',
  ), // flame
  Icons.link => const IconData(0xe2e2, fontFamily: 'PhosphorRegular'), // link
  Icons.light_mode_outlined => const IconData(
    0xe472,
    fontFamily: 'PhosphorRegular',
  ), // sun
  Icons.lightbulb_outline_rounded => const IconData(
    0xe2dc,
    fontFamily: 'PhosphorRegular',
  ), // lightbulb
  Icons.laptop_mac_outlined => const IconData(
    0xe586,
    fontFamily: 'PhosphorRegular',
  ), // laptop
  Icons.keyboard_outlined => const IconData(
    0xe2d8,
    fontFamily: 'PhosphorRegular',
  ), // keyboard
  Icons.inbox_rounded => const IconData(
    0xe4aa,
    fontFamily: 'PhosphorRegular',
  ), // tray
  Icons.image_outlined => const IconData(
    0xe2ca,
    fontFamily: 'PhosphorRegular',
  ), // image
  Icons.home_outlined => const IconData(
    0xe2c2,
    fontFamily: 'PhosphorRegular',
  ), // house
  Icons.gpp_maybe_outlined => const IconData(
    0xe412,
    fontFamily: 'PhosphorRegular',
  ), // shieldWarning
  Icons.format_strikethrough => const IconData(
    0xe5c2,
    fontFamily: 'PhosphorRegular',
  ), // textStrikethrough
  Icons.format_quote => const IconData(
    0xe660,
    fontFamily: 'PhosphorRegular',
  ), // quotes
  Icons.format_list_numbered => const IconData(
    0xe2f6,
    fontFamily: 'PhosphorRegular',
  ), // listNumbers
  Icons.format_list_bulleted => const IconData(
    0xe2f2,
    fontFamily: 'PhosphorRegular',
  ), // listBullets
  Icons.format_italic => const IconData(
    0xe5c0,
    fontFamily: 'PhosphorRegular',
  ), // textItalic
  Icons.format_bold => const IconData(
    0xe5be,
    fontFamily: 'PhosphorRegular',
  ), // textB
  Icons.folder => const IconData(0xe24a, fontFamily: 'PhosphorFill'), // folder
  Icons.flight_takeoff_rounded => const IconData(
    0xe504,
    fontFamily: 'PhosphorRegular',
  ), // airplaneTakeoff
  Icons.fitness_center_rounded => const IconData(
    0xe0b6,
    fontFamily: 'PhosphorRegular',
  ), // barbell
  Icons.file_upload_outlined => const IconData(
    0xe4c0,
    fontFamily: 'PhosphorRegular',
  ), // uploadSimple
  Icons.file_download_outlined => const IconData(
    0xe20c,
    fontFamily: 'PhosphorRegular',
  ), // downloadSimple
  Icons.favorite_outline_rounded => const IconData(
    0xe2a8,
    fontFamily: 'PhosphorRegular',
  ), // heart
  Icons.expand_more_rounded => const IconData(
    0xe136,
    fontFamily: 'PhosphorRegular',
  ), // caretDown
  Icons.expand_more => const IconData(
    0xe136,
    fontFamily: 'PhosphorRegular',
  ), // caretDown
  Icons.expand_less_rounded => const IconData(
    0xe13c,
    fontFamily: 'PhosphorRegular',
  ), // caretUp
  Icons.expand_less => const IconData(
    0xe13c,
    fontFamily: 'PhosphorRegular',
  ), // caretUp
  Icons.event_rounded => const IconData(
    0xe108,
    fontFamily: 'PhosphorRegular',
  ), // calendar
  Icons.event_busy_rounded => const IconData(
    0xe10c,
    fontFamily: 'PhosphorRegular',
  ), // calendarX
  Icons.event => const IconData(0xe108, fontFamily: 'PhosphorFill'), // calendar
  Icons.emoji_events_rounded => const IconData(
    0xe67e,
    fontFamily: 'PhosphorFill',
  ), // trophy
  Icons.emoji_events_outlined => const IconData(
    0xe67e,
    fontFamily: 'PhosphorRegular',
  ), // trophy
  Icons.edit_calendar_rounded => const IconData(
    0xe714,
    fontFamily: 'PhosphorRegular',
  ), // calendarPlus
  Icons.drag_handle_rounded => const IconData(
    0xe794,
    fontFamily: 'PhosphorRegular',
  ), // dotsSix
  Icons.dns_outlined => const IconData(
    0xe2a0,
    fontFamily: 'PhosphorRegular',
  ), // hardDrives
  Icons.delete_outline => const IconData(
    0xe4a6,
    fontFamily: 'PhosphorRegular',
  ), // trash
  Icons.date_range_rounded => const IconData(
    0xe10a,
    fontFamily: 'PhosphorRegular',
  ), // calendarBlank
  Icons.data_object => const IconData(
    0xe860,
    fontFamily: 'PhosphorRegular',
  ), // bracketsCurly
  Icons.dark_mode_outlined => const IconData(
    0xe330,
    fontFamily: 'PhosphorRegular',
  ), // moon
  Icons.copy_rounded => const IconData(
    0xe1ca,
    fontFamily: 'PhosphorRegular',
  ), // copy
  Icons.code => const IconData(0xe1bc, fontFamily: 'PhosphorRegular'), // code
  Icons.cloud_done_outlined => const IconData(
    0xe1b0,
    fontFamily: 'PhosphorRegular',
  ), // cloudCheck
  Icons.close => const IconData(0xe4f6, fontFamily: 'PhosphorRegular'), // x
  Icons.clear_rounded => const IconData(
    0xe4f6,
    fontFamily: 'PhosphorRegular',
  ), // x
  Icons.check_circle_rounded => const IconData(
    0xe184,
    fontFamily: 'PhosphorFill',
  ), // checkCircle
  Icons.check_circle_outline_rounded => const IconData(
    0xe184,
    fontFamily: 'PhosphorRegular',
  ), // checkCircle
  Icons.check_circle => const IconData(
    0xe184,
    fontFamily: 'PhosphorFill',
  ), // checkCircle
  Icons.check_box_outlined => const IconData(
    0xe186,
    fontFamily: 'PhosphorRegular',
  ), // checkSquare
  Icons.check => const IconData(0xe182, fontFamily: 'PhosphorRegular'), // check
  Icons.celebration_outlined => const IconData(
    0xe81a,
    fontFamily: 'PhosphorRegular',
  ), // confetti
  Icons.calendar_today_rounded => const IconData(
    0xe10a,
    fontFamily: 'PhosphorRegular',
  ), // calendarBlank
  Icons.brightness_auto_outlined => const IconData(
    0xe18c,
    fontFamily: 'PhosphorRegular',
  ), // circleHalf
  Icons.auto_awesome_rounded => const IconData(
    0xe6a2,
    fontFamily: 'PhosphorRegular',
  ), // sparkle
  Icons.arrow_upward_rounded => const IconData(
    0xe08e,
    fontFamily: 'PhosphorRegular',
  ), // arrowUp
  Icons.arrow_back_ios_new_rounded => const IconData(
    0xe138,
    fontFamily: 'PhosphorRegular',
  ), // caretLeft
  Icons.android_rounded => const IconData(
    0xe008,
    fontFamily: 'PhosphorRegular',
  ), // androidLogo
  Icons.add_circle_outline_rounded => const IconData(
    0xe3d6,
    fontFamily: 'PhosphorRegular',
  ), // plusCircle
  Icons.add_a_photo_outlined => const IconData(
    0xe10e,
    fontFamily: 'PhosphorRegular',
  ), // camera
  Icons.add => const IconData(0xe3d4, fontFamily: 'PhosphorRegular'), // plus
  Icons.account_circle_outlined => const IconData(
    0xe4c4,
    fontFamily: 'PhosphorRegular',
  ), // userCircle
  Icons.access_time_rounded => const IconData(
    0xe19a,
    fontFamily: 'PhosphorRegular',
  ), // clock
  _ => null,
};
