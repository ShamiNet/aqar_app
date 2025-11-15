import 'package:cloudinary_public/cloudinary_public.dart';

// استبدل القيم أدناه بقيم حسابك في Cloudinary
const String cloudinaryCloudName = 'dvocrpapc';
const String cloudinaryUploadPreset = 'ml_default';

final CloudinaryPublic cloudinary = CloudinaryPublic(
  cloudinaryCloudName,
  cloudinaryUploadPreset,
  cache: false,
);
