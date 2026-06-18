import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Single chokepoint mapping semantic names to Lucide [IconData].
///
/// Every icon in the app routes through here, so swapping the icon source
/// (e.g. to a Material fallback if the Lucide package is ever unavailable) is a
/// one-file change. Names mirror the design handoff's Lucide usage.
class AppIcons {
  const AppIcons._();

  // Navigation / chrome
  static const IconData house = LucideIcons.house;
  static const IconData chartPie = LucideIcons.chartPie;
  static const IconData settings = LucideIcons.settings;
  static const IconData plus = LucideIcons.plus;
  static const IconData arrowLeft = LucideIcons.arrowLeft;
  static const IconData arrowRight = LucideIcons.arrowRight;
  static const IconData arrowDown = LucideIcons.arrowDown;
  static const IconData arrowUpRight = LucideIcons.arrowUpRight;
  static const IconData arrowDownLeft = LucideIcons.arrowDownLeft;
  static const IconData arrowLeftRight = LucideIcons.arrowLeftRight;
  static const IconData chevronLeft = LucideIcons.chevronLeft;
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData x = LucideIcons.x;
  static const IconData check = LucideIcons.check;
  static const IconData search = LucideIcons.search;
  static const IconData ellipsis = LucideIcons.ellipsis;
  static const IconData clock = LucideIcons.clock;
  static const IconData info = LucideIcons.info;

  // Status bar
  static const IconData signal = LucideIcons.signal;
  static const IconData wifi = LucideIcons.wifi;
  static const IconData batteryMedium = LucideIcons.batteryMedium;

  // Money / transactions
  static const IconData wallet = LucideIcons.wallet;
  static const IconData banknote = LucideIcons.banknote;
  static const IconData receipt = LucideIcons.receipt;
  static const IconData receiptText = LucideIcons.receiptText;
  static const IconData rotateCw = LucideIcons.rotateCw;
  static const IconData loader = LucideIcons.loader;
  static const IconData scanLine = LucideIcons.scanLine;
  static const IconData store = LucideIcons.store;
  static const IconData repeat = LucideIcons.repeat;
  static const IconData calendar = LucideIcons.calendar;
  static const IconData layoutGrid = LucideIcons.layoutGrid;
  static const IconData hash = LucideIcons.hash;
  static const IconData pencil = LucideIcons.pencil;
  static const IconData pencilLine = LucideIcons.pencilLine;
  static const IconData trash2 = LucideIcons.trash2;
  static const IconData gripVertical = LucideIcons.gripVertical;
  static const IconData trendingDown = LucideIcons.trendingDown;
  static const IconData target = LucideIcons.target;
  static const IconData bell = LucideIcons.bell;
  static const IconData bellRing = LucideIcons.bellRing;

  // Categories
  static const IconData utensils = LucideIcons.utensils;
  static const IconData coffee = LucideIcons.coffee;
  static const IconData shoppingBag = LucideIcons.shoppingBag;
  static const IconData bus = LucideIcons.bus;
  static const IconData trainFront = LucideIcons.trainFront;
  static const IconData package = LucideIcons.package;
  static const IconData clapperboard = LucideIcons.clapperboard;
  static const IconData heartPulse = LucideIcons.heartPulse;
  static const IconData pawPrint = LucideIcons.pawPrint;
  static const IconData gift = LucideIcons.gift;
  static const IconData palmtree = LucideIcons.palmtree;
  static const IconData graduationCap = LucideIcons.graduationCap;
  static const IconData briefcase = LucideIcons.briefcase;
  static const IconData dumbbell = LucideIcons.dumbbell;
  static const IconData plane = LucideIcons.plane;

  // Accounts / banks (generic placeholders for bank logos)
  static const IconData landmark = LucideIcons.landmark;
  static const IconData creditCard = LucideIcons.creditCard;
  static const IconData sprout = LucideIcons.sprout;
  static const IconData gem = LucideIcons.gem;
  static const IconData droplet = LucideIcons.droplet;
  static const IconData building2 = LucideIcons.building2;

  // Auth / settings
  static const IconData mail = LucideIcons.mail;
  static const IconData lock = LucideIcons.lock;
  static const IconData lockKeyhole = LucideIcons.lockKeyhole;
  static const IconData keyRound = LucideIcons.keyRound;
  static const IconData eye = LucideIcons.eye;
  static const IconData eyeOff = LucideIcons.eyeOff;
  static const IconData userRound = LucideIcons.userRound;
  static const IconData globe = LucideIcons.globe;
  static const IconData google = LucideIcons.globe; // Lucide dropped "chrome"
  static const IconData apple = LucideIcons.apple;
  static const IconData palette = LucideIcons.palette;
  static const IconData shield = LucideIcons.shield;
  static const IconData shieldCheck = LucideIcons.shieldCheck;
  static const IconData scanFace = LucideIcons.scanFace;
  static const IconData circleHelp = LucideIcons.circleHelp;
  static const IconData logOut = LucideIcons.logOut;
  static const IconData download = LucideIcons.download;
  static const IconData messageCircle = LucideIcons.messageCircle;
  static const IconData camera = LucideIcons.camera;
  static const IconData partyPopper = LucideIcons.partyPopper;
}
