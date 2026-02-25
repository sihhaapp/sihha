const fs = require("fs");
const path = require("path");
const express = require("express");
const cors = require("cors");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const multer = require("multer");
const { AccessToken } = require("livekit-server-sdk");
const { v4: uuidv4 } = require("uuid");
let OpenAI = null;
try {
  OpenAI = require("openai");
} catch (_) {
  OpenAI = null;
}
require("dotenv").config();

const { initDb } = require("./db");

const PORT = Number(process.env.PORT || 3000);
const JWT_SECRET = process.env.JWT_SECRET || "dev-secret";
const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || "").trim();
const ADMIN_LOCAL_PHONE = "00000000";
const ADMIN_DISPLAY_PHONE = `+235${ADMIN_LOCAL_PHONE}`;
const ADMIN_DEFAULT_PASSWORD = "0412";
const ADMIN_DEFAULT_NAME = "General Admin";
const LIVE_ONLINE_WINDOW_MS = 15000;
const APP_ONLINE_WINDOW_MS = 5 * 60 * 1000;
const LIVE_STATUS_IDLE = "idle";
const LIVE_STATUS_PENDING = "pending";
const LIVE_STATUS_ACTIVE = "active";
const LIVE_MARKER_REQUEST = "[LIVE_REQUEST]";
const LIVE_MARKER_ACCEPT = "[LIVE_ACCEPT]";
const LIVE_MARKER_REJECT = "[LIVE_REJECT]";
const LIVE_MARKER_START = "[LIVE_START]";
const LIVE_MARKER_STOP = "[LIVE_STOP]";
const LIVE_MARKER_SIGNAL = "[LIVE_SIGNAL]";
const LIVEKIT_URL = (process.env.LIVEKIT_URL || "").trim();
const LIVEKIT_API_KEY = (process.env.LIVEKIT_API_KEY || "").trim();
const LIVEKIT_API_SECRET = (process.env.LIVEKIT_API_SECRET || "").trim();
const LIVEKIT_ROOM_PREFIX = (process.env.LIVEKIT_ROOM_PREFIX || "sihha").trim() || "sihha";
const LIVEKIT_TOKEN_TTL_SECONDS = Number(process.env.LIVEKIT_TOKEN_TTL_SECONDS || 900);
const CONSULTATION_SUBJECT_SELF = "self";
const CONSULTATION_SUBJECT_OTHER = "other";
const CONSULTATION_GENDER_MALE = "male";
const CONSULTATION_GENDER_FEMALE = "female";
const CONSULTATION_LANG_AR = "ar";
const CONSULTATION_LANG_FR = "fr";
const CONSULTATION_LANG_BILINGUAL = "bilingual";
const CONSULTATION_STATUS_PENDING = "pending";
const CONSULTATION_STATUS_ACCEPTED = "accepted";
const CONSULTATION_STATUS_REJECTED = "rejected";
const OPENAI_API_KEY = (process.env.OPENAI_API_KEY || "").trim();
const OPENAI_TRIAGE_MODEL = (process.env.OPENAI_TRIAGE_MODEL || "gpt-4o-mini").trim() || "gpt-4o-mini";
const TRIAGE_ENABLE_MODERATION = parseBooleanValue(
  process.env.TRIAGE_ENABLE_MODERATION,
  true,
);
const TRIAGE_RISK_VALUES = new Set(["low", "medium", "high", "emergency"]);
const TRIAGE_SPECIALTY_VALUES = new Set([
  "general_practice",
  "pediatrics",
  "gynecology",
  "emergency",
]);
const TRIAGE_RESPONSE_SCHEMA = {
  name: "triage_result",
  strict: true,
  schema: {
    type: "object",
    additionalProperties: false,
    properties: {
      risk_level: { type: "string", enum: ["low", "medium", "high", "emergency"] },
      red_flags: { type: "array", items: { type: "string" } },
      follow_up_questions: {
        type: "array",
        items: { type: "string" },
        minItems: 3,
        maxItems: 12,
      },
      suggested_specialty: {
        type: "string",
        enum: ["general_practice", "pediatrics", "gynecology", "emergency"],
      },
      self_care: { type: "array", items: { type: "string" } },
      seek_urgent_care_if: { type: "array", items: { type: "string" } },
      summary_for_doctor: { type: "string" },
    },
    required: [
      "risk_level",
      "red_flags",
      "follow_up_questions",
      "suggested_specialty",
      "self_care",
      "seek_urgent_care_if",
      "summary_for_doctor",
    ],
  },
};
const CHAD_STATE_CODES = new Set([
  "barh_el_gazel",
  "batha",
  "borkou",
  "chari_baguirmi",
  "ennedi_est",
  "ennedi_ouest",
  "guera",
  "hadjer_lamis",
  "kanem",
  "lac",
  "logone_occidental",
  "logone_oriental",
  "mandoul",
  "mayo_kebbi_est",
  "mayo_kebbi_ouest",
  "moyen_chari",
  "n_djamena",
  "ouaddai",
  "salamat",
  "sila",
  "tandjile",
  "tibesti",
  "wadi_fira",
]);

const app = express();
app.use(cors());
app.use(express.json({ limit: "6mb" }));

app.use((req, res, next) => {
  const startedAt = Date.now();
  res.on("finish", () => {
    const elapsedMs = Date.now() - startedAt;
    // eslint-disable-next-line no-console
    console.log(`${req.method} ${req.originalUrl} -> ${res.statusCode} (${elapsedMs}ms)`);
  });
  next();
});

const uploadsRoot = path.resolve(__dirname, "..", "uploads");
fs.mkdirSync(uploadsRoot, { recursive: true });
app.use("/uploads", express.static(uploadsRoot));

let db;
let openAiClient = null;

function apiError(res, status, code, message) {
  return res.status(status).json({ code, message });
}

function toIsoNow() {
  return new Date().toISOString();
}

function toIsoDate(isoDateTime) {
  return String(isoDateTime || "").slice(0, 10);
}

function parseBooleanValue(value, fallback = false) {
  if (typeof value === "boolean") {
    return value;
  }
  if (typeof value === "number") {
    return value !== 0;
  }
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    if (!normalized) return fallback;
    if (["1", "true", "yes", "on"].includes(normalized)) return true;
    if (["0", "false", "no", "off"].includes(normalized)) return false;
  }
  return fallback;
}

function normalizeTriagePayload(body) {
  const age = Number(body?.age);
  const sex = String(body?.sex || "").trim().toLowerCase();
  const weightKg = Number(body?.weightKg);
  const pregnant = parseBooleanValue(body?.pregnant, false);
  const symptoms = String(body?.symptoms || "").trim();
  const duration = String(body?.duration || "").trim();
  const language = String(body?.language || "").trim().toLowerCase() === "fr" ? "fr" : "ar";

  if (!Number.isInteger(age) || age < 0 || age > 120) {
    return { error: "triage-invalid-age", message: "age must be an integer between 0 and 120." };
  }
  if (sex !== "male" && sex !== "female") {
    return { error: "triage-invalid-sex", message: "sex must be male or female." };
  }
  if (!Number.isFinite(weightKg) || weightKg < 1 || weightKg > 400) {
    return { error: "triage-invalid-weight", message: "weightKg must be between 1 and 400." };
  }
  if (sex === "male" && pregnant) {
    return {
      error: "triage-invalid-pregnancy",
      message: "pregnant cannot be true for male sex.",
    };
  }
  if (symptoms.length < 5 || symptoms.length > 3000) {
    return {
      error: "triage-invalid-symptoms",
      message: "symptoms must be between 5 and 3000 characters.",
    };
  }
  if (duration.length < 1 || duration.length > 120) {
    return {
      error: "triage-invalid-duration",
      message: "duration must be between 1 and 120 characters.",
    };
  }

  return {
    age,
    sex,
    weightKg: Number(weightKg.toFixed(2)),
    pregnant,
    symptoms,
    duration,
    language,
  };
}

function defaultFollowUpQuestions(language) {
  if (language === "fr") {
    return [
      "Y a-t-il une douleur thoracique importante ?",
      "Avez-vous une mesure de saturation en oxygene (SpO2) ?",
      "Les symptomes s aggravent-ils rapidement ?",
    ];
  }
  return [
    "هل يوجد ألم صدر شديد؟",
    "هل قياس الأكسجين (SpO2) متاح؟",
    "هل الأعراض تتفاقم بسرعة؟",
  ];
}

function defaultSelfCareTips(language) {
  if (language === "fr") {
    return [
      "Hydratez-vous regulierement.",
      "Surveillez la temperature et l evolution des symptomes.",
    ];
  }
  return [
    "اشرب سوائل بانتظام.",
    "راقب الحرارة وتطور الأعراض.",
  ];
}

function defaultUrgentCareTriggers(language) {
  if (language === "fr") {
    return [
      "Aggravation de la difficulte respiratoire.",
      "Perte de connaissance, confusion, ou douleur thoracique severe.",
      "Si les symptomes deviennent severes ou s aggravent, rendez-vous immediatement aux urgences.",
    ];
  }
  return [
    "تفاقم ضيق النفس.",
    "إغماء أو تشوش شديد أو ألم صدر قوي.",
    "إذا كانت الأعراض شديدة أو متفاقمة توجه للطوارئ فورًا.",
  ];
}

function normalizeStringList(value, maxItems = 12) {
  if (!Array.isArray(value)) {
    return [];
  }
  const seen = new Set();
  const result = [];
  for (const item of value) {
    const text = String(item || "").trim().slice(0, 280);
    if (!text || seen.has(text)) {
      continue;
    }
    seen.add(text);
    result.push(text);
    if (result.length >= maxItems) {
      break;
    }
  }
  return result;
}

function normalizeSpecialty(rawValue, riskLevel) {
  if (riskLevel === "emergency") {
    return "emergency";
  }
  const value = String(rawValue || "").trim().toLowerCase();
  if (!value) return "general_practice";
  if (TRIAGE_SPECIALTY_VALUES.has(value)) return value;
  if (["general", "general_medicine", "generalist", "medecin_generaliste"].includes(value)) {
    return "general_practice";
  }
  if (["pediatric", "pediatrician", "pediatre", "children"].includes(value)) {
    return "pediatrics";
  }
  if (["gynecology", "gynaecology", "gynecologue", "obgyn", "obstetrics"].includes(value)) {
    return "gynecology";
  }
  if (["urgent", "urgences", "er"].includes(value)) {
    return "emergency";
  }
  return "general_practice";
}

function normalizeTriageResult(rawResult, triageInput) {
  const language = triageInput.language;
  const rawRisk = String(rawResult?.risk_level || "").trim().toLowerCase();
  const riskLevel = TRIAGE_RISK_VALUES.has(rawRisk) ? rawRisk : "medium";

  const redFlags = normalizeStringList(rawResult?.red_flags, 12);
  let followUpQuestions = normalizeStringList(rawResult?.follow_up_questions, 12);
  if (followUpQuestions.length < 3) {
    for (const defaultQuestion of defaultFollowUpQuestions(language)) {
      if (!followUpQuestions.includes(defaultQuestion)) {
        followUpQuestions.push(defaultQuestion);
      }
      if (followUpQuestions.length >= 3) {
        break;
      }
    }
  }

  const selfCare = normalizeStringList(rawResult?.self_care, 12);
  if (selfCare.length === 0) {
    selfCare.push(...defaultSelfCareTips(language));
  }

  const seekUrgentCareIf = normalizeStringList(rawResult?.seek_urgent_care_if, 12);
  for (const urgentText of defaultUrgentCareTriggers(language)) {
    if (!seekUrgentCareIf.includes(urgentText)) {
      seekUrgentCareIf.push(urgentText);
    }
  }

  const suggestedSpecialty = normalizeSpecialty(rawResult?.suggested_specialty, riskLevel);
  const summaryRaw = String(rawResult?.summary_for_doctor || "").trim();
  const summaryForDoctor = summaryRaw
    ? summaryRaw.slice(0, 4000)
    : language === "fr"
      ? `Patient ${triageInput.sex === "female" ? "feminin" : "masculin"}, `
        + `${triageInput.age} ans, ${triageInput.weightKg} kg, symptomes: `
        + `${triageInput.symptoms}, duree: ${triageInput.duration}, `
        + `niveau de risque: ${riskLevel}, specialite suggeree: ${suggestedSpecialty}.`
      : `مريض ${triageInput.sex === "female" ? "أنثى" : "ذكر"}، `
        + `العمر ${triageInput.age} سنة، الوزن ${triageInput.weightKg} كغ، `
        + `الأعراض: ${triageInput.symptoms}، المدة: ${triageInput.duration}، `
        + `مستوى الخطورة: ${riskLevel}، التخصص المقترح: ${suggestedSpecialty}.`;

  return {
    risk_level: riskLevel,
    red_flags: redFlags,
    follow_up_questions: followUpQuestions.slice(0, 12),
    suggested_specialty: suggestedSpecialty,
    self_care: selfCare.slice(0, 12),
    seek_urgent_care_if: seekUrgentCareIf.slice(0, 12),
    summary_for_doctor: summaryForDoctor,
  };
}

function buildModerationFallback(input) {
  const language = input.language;
  if (language === "fr") {
    return {
      risk_level: "emergency",
      red_flags: ["Contenu sensible detecte"],
      follow_up_questions: defaultFollowUpQuestions("fr"),
      suggested_specialty: "emergency",
      self_care: defaultSelfCareTips("fr"),
      seek_urgent_care_if: defaultUrgentCareTriggers("fr"),
      summary_for_doctor:
        "Demande de triage marquee comme contenu sensible. Prioriser evaluation humaine immediate.",
    };
  }
  return {
    risk_level: "emergency",
    red_flags: ["تم رصد محتوى حساس"],
    follow_up_questions: defaultFollowUpQuestions("ar"),
    suggested_specialty: "emergency",
    self_care: defaultSelfCareTips("ar"),
    seek_urgent_care_if: defaultUrgentCareTriggers("ar"),
    summary_for_doctor:
      "تم تعليم طلب الفرز كمحتوى حساس. يوصى بتقييم بشري فوري.",
  };
}

function buildAiUnavailableFallback(input) {
  const language = input.language;
  if (language === "fr") {
    return {
      risk_level: "high",
      red_flags: ["Analyse IA temporairement indisponible"],
      follow_up_questions: defaultFollowUpQuestions("fr"),
      suggested_specialty: "general_practice",
      self_care: defaultSelfCareTips("fr"),
      seek_urgent_care_if: defaultUrgentCareTriggers("fr"),
      summary_for_doctor:
        "Analyse IA indisponible (erreur technique). Prioriser evaluation clinique humaine.",
    };
  }
  return {
    risk_level: "high",
    red_flags: ["خدمة التحليل الذكي غير متاحة مؤقتًا"],
    follow_up_questions: defaultFollowUpQuestions("ar"),
    suggested_specialty: "general_practice",
    self_care: defaultSelfCareTips("ar"),
    seek_urgent_care_if: defaultUrgentCareTriggers("ar"),
    summary_for_doctor:
      "تعذر تنفيذ تحليل الذكاء الاصطناعي بسبب خطأ تقني. يُنصح بتقييم طبي بشري مباشر.",
  };
}

function getOpenAiClient() {
  if (!OpenAI || !OPENAI_API_KEY) {
    return null;
  }
  if (!openAiClient) {
    openAiClient = new OpenAI({ apiKey: OPENAI_API_KEY });
  }
  return openAiClient;
}

function isModerationFlagged(moderationResponse) {
  const results = Array.isArray(moderationResponse?.results) ? moderationResponse.results : [];
  if (results.length === 0) {
    return false;
  }
  return results.some((item) => Boolean(item?.flagged));
}

function parseJsonObjectFromText(rawText) {
  const text = String(rawText || "").trim();
  if (!text) {
    throw new Error("triage-empty-output");
  }
  try {
    return JSON.parse(text);
  } catch (_) {
    const firstBrace = text.indexOf("{");
    const lastBrace = text.lastIndexOf("}");
    if (firstBrace === -1 || lastBrace === -1 || lastBrace <= firstBrace) {
      throw new Error("triage-invalid-json-output");
    }
    return JSON.parse(text.slice(firstBrace, lastBrace + 1));
  }
}

function extractTriageResponseObject(response) {
  if (response && typeof response.output_parsed === "object" && response.output_parsed) {
    return response.output_parsed;
  }
  if (response && typeof response.output_text === "string" && response.output_text.trim()) {
    return parseJsonObjectFromText(response.output_text);
  }

  const output = Array.isArray(response?.output) ? response.output : [];
  for (const item of output) {
    const contentList = Array.isArray(item?.content) ? item.content : [];
    for (const content of contentList) {
      if (content && typeof content.parsed === "object" && content.parsed) {
        return content.parsed;
      }
      if (content && typeof content.json === "object" && content.json) {
        return content.json;
      }
      if (typeof content?.text === "string" && content.text.trim()) {
        return parseJsonObjectFromText(content.text);
      }
    }
  }

  throw new Error("triage-empty-output");
}

async function requestStructuredTriageResponse(client, inputMessages) {
  try {
    return await client.responses.create({
      model: OPENAI_TRIAGE_MODEL,
      input: inputMessages,
      response_format: {
        type: "json_schema",
        json_schema: TRIAGE_RESPONSE_SCHEMA,
      },
    });
  } catch (_firstError) {
    return client.responses.create({
      model: OPENAI_TRIAGE_MODEL,
      input: inputMessages,
      text: {
        format: {
          type: "json_schema",
          name: TRIAGE_RESPONSE_SCHEMA.name,
          schema: TRIAGE_RESPONSE_SCHEMA.schema,
          strict: true,
        },
      },
    });
  }
}

async function insertTriageAuditLog({
  userId,
  input,
  result,
  moderationFlagged,
  status,
  errorCode = null,
  errorMessage = null,
}) {
  try {
    await db.run(
      `INSERT INTO triage_audit_logs (
         id, user_id, age_years, sex, weight_kg, pregnant,
         symptoms, duration_text, language, risk_level, suggested_specialty,
         red_flags, follow_up_questions, self_care, seek_urgent_care_if, summary_for_doctor,
         model_name, moderation_flagged, status, error_code, error_message, created_at
       ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      uuidv4(),
      userId || null,
      Number(input?.age || 0),
      String(input?.sex || ""),
      Number(input?.weightKg || 0),
      input?.pregnant ? 1 : 0,
      String(input?.symptoms || ""),
      String(input?.duration || ""),
      String(input?.language || "ar"),
      result ? result.risk_level : null,
      result ? result.suggested_specialty : null,
      JSON.stringify(result?.red_flags || []),
      JSON.stringify(result?.follow_up_questions || []),
      JSON.stringify(result?.self_care || []),
      JSON.stringify(result?.seek_urgent_care_if || []),
      String(result?.summary_for_doctor || ""),
      OPENAI_TRIAGE_MODEL,
      moderationFlagged ? 1 : 0,
      String(status || "unknown"),
      errorCode,
      errorMessage,
      toIsoNow(),
    );
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error("triage-audit-log-failed", error);
  }
}

function normalizeLocalPhoneDigits(phoneNumber) {
  let digits = String(phoneNumber || "").replace(/\D/g, "");
  if (digits.startsWith("235")) {
    digits = digits.slice(3);
  }
  if (digits === ADMIN_LOCAL_PHONE) {
    return digits;
  }
  digits = digits.replace(/^0+/, "");
  if (!digits) {
    throw new Error("invalid-phone-number");
  }
  return digits;
}

function toDisplayPhone(phoneNumber) {
  return `+235${normalizeLocalPhoneDigits(phoneNumber)}`;
}

function mapUserRow(row) {
  if (!row) return null;
  const phoneNumber = row.phone_number;
  return {
    id: row.id,
    name: row.name,
    phoneNumber,
    role: row.role,
    createdAt: row.created_at,
    photoUrl: row.photo_url,
    specialty: row.specialty,
    hospitalName: row.hospital_name,
    experienceYears: row.experience_years,
    studyYears: row.study_years,
    isDisabled: row.is_disabled === 1,
    disabledAt: row.disabled_at || null,
    lastSeenAt: row.last_seen_at || null,
    isAdmin: phoneNumber === ADMIN_DISPLAY_PHONE,
  };
}

function mapRoomRow(row) {
  if (!row) return null;
  return {
    id: row.id,
    patientId: row.patient_id,
    patientName: row.patient_name,
    doctorId: row.doctor_id,
    doctorName: row.doctor_name,
    participantIds: JSON.parse(row.participant_ids || "[]"),
    patientPhotoUrl: row.patient_photo_url || "",
    doctorPhotoUrl: row.doctor_photo_url || "",
    lastMessage: row.last_message,
    unreadCount: Number(row.unread_count || 0),
    createdAt: row.created_at,
    lastUpdatedAt: row.last_updated_at,
    isClosed: row.is_closed === 1,
  };
}

function mapConsultationRequestRow(row) {
  if (!row) return null;
  return {
    id: row.id,
    patientId: row.patient_id,
    targetDoctorId: row.target_doctor_id,
    subjectType: row.subject_type,
    subjectName: row.subject_name,
    ageYears: Number(row.age_years || 0),
    gender: row.gender,
    weightKg: Number(row.weight_kg || 0),
    stateCode: row.state_code,
    spokenLanguage: row.spoken_language,
    symptoms: row.symptoms,
    status: row.status,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    respondedAt: row.responded_at || null,
    respondedByDoctorId: row.responded_by_doctor_id || null,
    transferredByDoctorId: row.transferred_by_doctor_id || null,
    linkedRoomId: row.linked_room_id || null,
    patientName: row.patient_name || "",
    patientPhotoUrl: row.patient_photo_url || "",
    targetDoctorName: row.target_doctor_name || "",
    targetDoctorPhotoUrl: row.target_doctor_photo_url || "",
    respondedByDoctorName: row.responded_by_doctor_name || null,
    transferredByDoctorName: row.transferred_by_doctor_name || null,
  };
}

function mapMedicalRecordEntryRow(row, options = {}) {
  if (!row) return null;
  const includeSecretNotes = options.includeSecretNotes === true;
  return {
    id: row.id,
    patientId: row.patient_id,
    roomId: row.room_id,
    doctorId: row.doctor_id,
    doctorName: row.doctor_name || "",
    diagnosis: row.diagnosis || "",
    prescribedMedications: row.prescribed_medications || "",
    secretNotes: includeSecretNotes ? (row.secret_notes || "") : "",
    prescriptionPdfUrl: row.prescription_pdf_url || "",
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

function mapConsultationHistoryRow(row) {
  if (!row) return null;
  return {
    roomId: row.room_id,
    doctorId: row.doctor_id,
    doctorName: row.doctor_name || "",
    startedAt: row.started_at,
    lastUpdatedAt: row.last_updated_at,
    isClosed: row.is_closed === 1,
  };
}

function mapMessageRow(row) {
  if (!row) return null;
  return {
    id: row.id,
    roomId: row.room_id,
    senderId: row.sender_id,
    senderName: row.sender_name,
    type: row.type,
    content: row.content,
    durationSeconds: row.duration_seconds,
    deliveredAt: row.delivered_at,
    readAt: row.read_at,
    sentAt: row.sent_at,
  };
}

function mapBlogRow(row) {
  if (!row) return null;
  return {
    id: row.id,
    title: row.title,
    content: row.content,
    category: row.category,
    authorId: row.author_id,
    authorName: row.author_name,
    publishedAt: row.published_at,
    updatedAt: row.updated_at,
  };
}

function roomPreviewFromMessage(type, content) {
  if (type === "audio") {
    return "Voice message";
  }
  if (type === "image") {
    return "Image";
  }
  if (type === "live") {
    return `[LIVE] ${content || "Live update"}`.trim();
  }
  return content || "";
}

function issueToken(user) {
  return jwt.sign({ uid: user.id, role: user.role }, JWT_SECRET, {
    expiresIn: "30d",
  });
}

async function requireAuth(req, res, next) {
  const authHeader = req.headers.authorization || "";
  if (!authHeader.startsWith("Bearer ")) {
    return apiError(res, 401, "unauthorized", "Missing authorization token.");
  }

  const token = authHeader.slice(7);
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    const user = await db.get("SELECT * FROM users WHERE id = ?", payload.uid);
    if (!user) {
      return apiError(res, 401, "unauthorized", "Invalid session.");
    }
    if (user.is_disabled === 1) {
      return apiError(res, 403, "account-disabled", "This account has been disabled.");
    }
    await touchUserActivity(user.id);
    req.authUser = mapUserRow(user);
    return next();
  } catch (error) {
    if (error && (error.name === "JsonWebTokenError" || error.name === "TokenExpiredError")) {
      return apiError(res, 401, "unauthorized", "Invalid token.");
    }
    return apiError(res, 500, "auth-check-failed", "Unable to validate authentication.");
  }
}

function requireAdmin(req, res, next) {
  if (!req.authUser || req.authUser.phoneNumber !== ADMIN_DISPLAY_PHONE) {
    return apiError(res, 403, "forbidden", "Admin access required.");
  }
  return next();
}

function buildFileUrl(req, relativePath) {
  const baseUrl = PUBLIC_BASE_URL || `${req.protocol}://${req.get("host")}`;
  return `${baseUrl}/${relativePath.replace(/\\/g, "/")}`;
}

async function touchUserActivity(userId) {
  const now = toIsoNow();
  const today = toIsoDate(now);
  await db.run(
    `INSERT INTO app_presence (user_id, last_seen_at)
     VALUES (?, ?)
     ON CONFLICT(user_id) DO UPDATE SET
       last_seen_at = excluded.last_seen_at`,
    userId,
    now,
  );
  await db.run(
    `INSERT INTO user_daily_activity (user_id, activity_date, first_seen_at, last_seen_at)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(user_id, activity_date) DO UPDATE SET
       last_seen_at = excluded.last_seen_at`,
    userId,
    today,
    now,
    now,
  );
}

async function ensureAdminAccount() {
  const row = await db.get(
    "SELECT * FROM users WHERE phone_number = ?",
    ADMIN_DISPLAY_PHONE,
  );
  const now = toIsoNow();

  if (!row) {
    const hash = await bcrypt.hash(ADMIN_DEFAULT_PASSWORD, 12);
    await db.run(
      `INSERT INTO users (
        id, name, phone_number, password_hash, role, photo_url, specialty,
        hospital_name, experience_years, study_years, created_at
      ) VALUES (?, ?, ?, ?, 'patient', '', '', '', 0, 0, ?)`,
      "admin-root",
      ADMIN_DEFAULT_NAME,
      ADMIN_DISPLAY_PHONE,
      hash,
      now,
    );
    return;
  }

  await db.run(
    `UPDATE users
     SET name = ?, is_disabled = 0, disabled_at = NULL
     WHERE id = ?`,
    ADMIN_DEFAULT_NAME,
    row.id,
  );
}

function ensureParticipant(room, userId) {
  return room && (room.patient_id === userId || room.doctor_id === userId);
}

function buildRoomId(firstId, secondId) {
  const sorted = [firstId, secondId].sort();
  return `${sorted[0]}_${sorted[1]}`;
}

async function getRoomWithPhotos(roomId) {
  return db.get(
    `SELECT
      r.*,
      p.photo_url AS patient_photo_url,
      d.photo_url AS doctor_photo_url
    FROM rooms r
    JOIN users p ON p.id = r.patient_id
    JOIN users d ON d.id = r.doctor_id
    WHERE r.id = ?`,
    roomId,
  );
}

async function listRoomsWithPhotosByUser(userId, role) {
  const field = role === "doctor" ? "r.doctor_id" : "r.patient_id";
  return db.all(
    `SELECT
      r.*,
      p.photo_url AS patient_photo_url,
      d.photo_url AS doctor_photo_url,
      (
        SELECT COUNT(1)
        FROM messages m
        WHERE m.room_id = r.id
          AND m.sender_id != ?
          AND m.read_at IS NULL
      ) AS unread_count
    FROM rooms r
    JOIN users p ON p.id = r.patient_id
    JOIN users d ON d.id = r.doctor_id
    WHERE ${field} = ?
    ORDER BY datetime(r.last_updated_at) DESC`,
    userId,
    userId,
  );
}

async function createOrGetRoomForUsers(patient, doctor) {
  const roomId = buildRoomId(patient.id, doctor.id);
  const existing = await getRoomWithPhotos(roomId);
  if (existing) {
    if (existing.is_closed === 1 || existing.is_closed === true) {
      const now = toIsoNow();
      await db.run(
        `UPDATE rooms
         SET is_closed = 0,
             last_updated_at = ?
         WHERE id = ?`,
        now,
        roomId,
      );
      return getRoomWithPhotos(roomId);
    }
    return existing;
  }

  const now = toIsoNow();
  await db.run(
    `INSERT INTO rooms (
      id, patient_id, patient_name, doctor_id, doctor_name, participant_ids,
      last_message, created_at, last_updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, '', ?, ?)`,
    roomId,
    patient.id,
    patient.name,
    doctor.id,
    doctor.name,
    JSON.stringify([patient.id, doctor.id]),
    now,
    now,
  );

  return getRoomWithPhotos(roomId);
}

async function getConsultationRequestWithDetailsById(requestId) {
  return db.get(
    `SELECT
      cr.*,
      p.name AS patient_name,
      p.photo_url AS patient_photo_url,
      d.name AS target_doctor_name,
      d.photo_url AS target_doctor_photo_url,
      rd.name AS responded_by_doctor_name,
      td.name AS transferred_by_doctor_name
    FROM consultation_requests cr
    JOIN users p ON p.id = cr.patient_id
    JOIN users d ON d.id = cr.target_doctor_id
    LEFT JOIN users rd ON rd.id = cr.responded_by_doctor_id
    LEFT JOIN users td ON td.id = cr.transferred_by_doctor_id
    WHERE cr.id = ?`,
    requestId,
  );
}

async function listConsultationRequestsByPatient(patientId) {
  return db.all(
    `SELECT
      cr.*,
      p.name AS patient_name,
      p.photo_url AS patient_photo_url,
      d.name AS target_doctor_name,
      d.photo_url AS target_doctor_photo_url,
      rd.name AS responded_by_doctor_name,
      td.name AS transferred_by_doctor_name
    FROM consultation_requests cr
    JOIN users p ON p.id = cr.patient_id
    JOIN users d ON d.id = cr.target_doctor_id
    LEFT JOIN users rd ON rd.id = cr.responded_by_doctor_id
    LEFT JOIN users td ON td.id = cr.transferred_by_doctor_id
    WHERE cr.patient_id = ?
    ORDER BY datetime(cr.updated_at) DESC`,
    patientId,
  );
}

async function listConsultationRequestsInboxForDoctor(doctorId) {
  return db.all(
    `SELECT
      cr.*,
      p.name AS patient_name,
      p.photo_url AS patient_photo_url,
      d.name AS target_doctor_name,
      d.photo_url AS target_doctor_photo_url,
      rd.name AS responded_by_doctor_name,
      td.name AS transferred_by_doctor_name
    FROM consultation_requests cr
    JOIN users p ON p.id = cr.patient_id
    JOIN users d ON d.id = cr.target_doctor_id
    LEFT JOIN users rd ON rd.id = cr.responded_by_doctor_id
    LEFT JOIN users td ON td.id = cr.transferred_by_doctor_id
    WHERE cr.target_doctor_id = ?
      AND cr.status = ?
    ORDER BY datetime(cr.updated_at) DESC`,
    doctorId,
    CONSULTATION_STATUS_PENDING,
  );
}

async function getConsultationRequestByRoom(room) {
  const byLinked = await db.get(
    `SELECT
      cr.*,
      p.name AS patient_name,
      p.photo_url AS patient_photo_url,
      d.name AS target_doctor_name,
      d.photo_url AS target_doctor_photo_url,
      rd.name AS responded_by_doctor_name,
      td.name AS transferred_by_doctor_name
    FROM consultation_requests cr
    JOIN users p ON p.id = cr.patient_id
    JOIN users d ON d.id = cr.target_doctor_id
    LEFT JOIN users rd ON rd.id = cr.responded_by_doctor_id
    LEFT JOIN users td ON td.id = cr.transferred_by_doctor_id
    WHERE cr.linked_room_id = ?
    ORDER BY datetime(cr.updated_at) DESC
    LIMIT 1`,
    room.id,
  );
  if (byLinked) return byLinked;

  // Fallback: آخر طلب بين نفس المريض/الطبيب إذا لم يكن linked_room_id مضبوطاً
  return db.get(
    `SELECT
      cr.*,
      p.name AS patient_name,
      p.photo_url AS patient_photo_url,
      d.name AS target_doctor_name,
      d.photo_url AS target_doctor_photo_url,
      rd.name AS responded_by_doctor_name,
      td.name AS transferred_by_doctor_name
    FROM consultation_requests cr
    JOIN users p ON p.id = cr.patient_id
    JOIN users d ON d.id = cr.target_doctor_id
    LEFT JOIN users rd ON rd.id = cr.responded_by_doctor_id
    LEFT JOIN users td ON td.id = cr.transferred_by_doctor_id
    WHERE cr.patient_id = ?
      AND cr.target_doctor_id = ?
    ORDER BY datetime(cr.updated_at) DESC
    LIMIT 1`,
    room.patient_id,
    room.doctor_id,
  );
}

async function getPatientMedicalRecordRow(patientId) {
  return db.get(
    `SELECT patient_id, allergies, chronic_diseases, created_at, updated_at
     FROM patient_medical_records
     WHERE patient_id = ?`,
    patientId,
  );
}

async function listMedicalRecordEntriesByPatient(patientId) {
  return db.all(
    `SELECT
      e.*,
      d.name AS doctor_name
     FROM medical_record_entries e
     JOIN users d ON d.id = e.doctor_id
     WHERE e.patient_id = ?
     ORDER BY datetime(e.updated_at) DESC`,
    patientId,
  );
}

async function listConsultationHistoryByPatient(patientId) {
  return db.all(
    `SELECT
      r.id AS room_id,
      r.doctor_id,
      r.doctor_name,
      r.created_at AS started_at,
      r.last_updated_at,
      r.is_closed
     FROM rooms r
     WHERE r.patient_id = ?
     ORDER BY datetime(r.last_updated_at) DESC`,
    patientId,
  );
}

function uniqueNonEmpty(values) {
  const seen = new Set();
  const result = [];
  for (const raw of values) {
    const value = String(raw || "").trim();
    if (!value || seen.has(value)) {
      continue;
    }
    seen.add(value);
    result.push(value);
  }
  return result;
}

function getLatestPrescriptionPdfUrl(entryRows) {
  const match = (entryRows || []).find((row) => String(row.prescription_pdf_url || "").trim());
  if (!match) return null;
  return String(match.prescription_pdf_url || "").trim() || null;
}

async function buildMedicalRecordPayload({
  patientId,
  viewerRole,
  viewerUserId,
}) {
  const [profileRow, entryRows, historyRows] = await Promise.all([
    getPatientMedicalRecordRow(patientId),
    listMedicalRecordEntriesByPatient(patientId),
    listConsultationHistoryByPatient(patientId),
  ]);

  const canSeeSecretForRow = (row) => viewerRole === "doctor" && row.doctor_id === viewerUserId;
  const entries = entryRows.map((row) =>
    mapMedicalRecordEntryRow(row, {
      includeSecretNotes: canSeeSecretForRow(row),
    }));

  const previousDiagnoses = uniqueNonEmpty(entryRows.map((row) => row.diagnosis));
  const prescribedMedications = uniqueNonEmpty(entryRows.map((row) => row.prescribed_medications));

  return {
    patientId,
    allergies: profileRow?.allergies || "",
    chronicDiseases: profileRow?.chronic_diseases || "",
    consultationHistory: historyRows.map(mapConsultationHistoryRow).filter(Boolean),
    previousDiagnoses,
    prescribedMedications,
    latestPrescriptionPdfUrl: getLatestPrescriptionPdfUrl(entryRows),
    updatedAt: profileRow?.updated_at || entryRows[0]?.updated_at || null,
    entries,
  };
}

function normalizeConsultationPayload(reqBody, patientUser) {
  const doctorId = String(reqBody.doctorId || "").trim();
  const subjectType = String(reqBody.subjectType || "").trim();
  const rawSubjectName = String(reqBody.subjectName || "").trim();
  const ageYears = Number(reqBody.ageYears);
  const gender = String(reqBody.gender || "").trim();
  const weightKg = Number(reqBody.weightKg);
  const stateCode = String(reqBody.stateCode || "").trim().toLowerCase();
  const spokenLanguage = String(reqBody.spokenLanguage || "").trim().toLowerCase();
  const symptoms = String(reqBody.symptoms || "").trim();

  const validSubjectType =
    subjectType === CONSULTATION_SUBJECT_SELF ||
    subjectType === CONSULTATION_SUBJECT_OTHER;
  if (!doctorId) {
    return { error: "doctor-required", message: "doctorId is required." };
  }
  if (!validSubjectType) {
    return {
      error: "consultation-subject-type-invalid",
      message: "subjectType must be self or other.",
    };
  }
  const subjectName = subjectType === CONSULTATION_SUBJECT_SELF
    ? String(patientUser.name || "").trim()
    : rawSubjectName;
  if (!subjectName || subjectName.length < 2) {
    return {
      error: "consultation-subject-name-required",
      message: "Subject name is required.",
    };
  }
  if (!Number.isFinite(ageYears) || !Number.isInteger(ageYears) || ageYears < 0 || ageYears > 120) {
    return {
      error: "consultation-age-invalid",
      message: "ageYears must be an integer between 0 and 120.",
    };
  }
  if (gender !== CONSULTATION_GENDER_MALE && gender !== CONSULTATION_GENDER_FEMALE) {
    return {
      error: "consultation-gender-invalid",
      message: "gender must be male or female.",
    };
  }
  if (!Number.isFinite(weightKg) || weightKg < 1 || weightKg > 400) {
    return {
      error: "consultation-weight-invalid",
      message: "weightKg must be between 1 and 400.",
    };
  }
  if (!CHAD_STATE_CODES.has(stateCode)) {
    return {
      error: "consultation-state-invalid",
      message: "stateCode is invalid.",
    };
  }
  if (
    spokenLanguage !== CONSULTATION_LANG_AR
    && spokenLanguage !== CONSULTATION_LANG_FR
    && spokenLanguage !== CONSULTATION_LANG_BILINGUAL
  ) {
    return {
      error: "consultation-language-invalid",
      message: "spokenLanguage must be ar, fr, or bilingual.",
    };
  }
  if (symptoms.length < 5 || symptoms.length > 2000) {
    return {
      error: "consultation-symptoms-invalid",
      message: "symptoms must be between 5 and 2000 characters.",
    };
  }

  return {
    doctorId,
    subjectType,
    subjectName,
    ageYears,
    gender,
    weightKg,
    stateCode,
    spokenLanguage,
    symptoms,
  };
}

async function updateRoomPresence(roomId, userId, isActive = true) {
  const now = toIsoNow();
  await db.run(
    `INSERT INTO room_presence (room_id, user_id, last_seen_at, is_active)
     VALUES (?, ?, ?, ?)
     ON CONFLICT(room_id, user_id)
     DO UPDATE SET
       last_seen_at = excluded.last_seen_at,
       is_active = excluded.is_active`,
    roomId,
    userId,
    now,
    isActive ? 1 : 0,
  );
}

function isPresenceFresh(lastSeenAt) {
  const ms = Date.parse(lastSeenAt || "");
  if (Number.isNaN(ms)) {
    return false;
  }
  return Date.now() - ms <= LIVE_ONLINE_WINDOW_MS;
}

async function isOtherParticipantOnline(room, currentUserId) {
  const otherUserId = room.patient_id === currentUserId
    ? room.doctor_id
    : room.patient_id;
  const otherPresence = await db.get(
    `SELECT last_seen_at, is_active
     FROM room_presence
     WHERE room_id = ? AND user_id = ?`,
    room.id,
    otherUserId,
  );
  return Boolean(
    otherPresence
      && otherPresence.is_active === 1
      && isPresenceFresh(otherPresence.last_seen_at),
  );
}

function getUtcDateBoundaries() {
  const now = new Date();
  const dayStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
  const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1));
  const yearStart = new Date(Date.UTC(now.getUTCFullYear(), 0, 1));
  return {
    dayStartIso: dayStart.toISOString(),
    monthStartIso: monthStart.toISOString(),
    yearStartIso: yearStart.toISOString(),
    dayDate: dayStart.toISOString().slice(0, 10),
    monthDate: monthStart.toISOString().slice(0, 10),
    yearDate: yearStart.toISOString().slice(0, 10),
  };
}

function isLiveKitConfigured() {
  return Boolean(LIVEKIT_URL && LIVEKIT_API_KEY && LIVEKIT_API_SECRET);
}

function getLiveKitTokenTtlSeconds() {
  if (!Number.isFinite(LIVEKIT_TOKEN_TTL_SECONDS)) {
    return 900;
  }
  return Math.max(60, Math.floor(LIVEKIT_TOKEN_TTL_SECONDS));
}

function sanitizeLiveKitSegment(value, fallback = "") {
  const cleaned = String(value || "").replace(/[^0-9A-Za-z_-]/g, "");
  return cleaned || fallback;
}

function buildLiveKitRoomName(roomId, session) {
  const roomSegment = sanitizeLiveKitSegment(roomId, "room");
  const sessionToken = sanitizeLiveKitSegment(
    session?.requestedAt || session?.respondedAt || "session",
    "session",
  );
  const prefix = sanitizeLiveKitSegment(LIVEKIT_ROOM_PREFIX, "sihha");
  return `${prefix}-${roomSegment}-${sessionToken}`.slice(0, 128);
}

async function issueLiveKitToken({
  roomName,
  identity,
  name,
}) {
  const accessToken = new AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET, {
    identity,
    name,
    ttl: `${getLiveKitTokenTtlSeconds()}s`,
  });
  accessToken.addGrant({
    roomJoin: true,
    room: roomName,
    canPublish: true,
    canPublishData: true,
    canSubscribe: true,
  });
  return accessToken.toJwt();
}

async function getLiveSession(roomId) {
  const row = await db.get(
    `SELECT room_id, status, requested_by, requested_at, responded_at
     FROM live_sessions
     WHERE room_id = ?`,
    roomId,
  );
  if (!row) {
    return {
      roomId,
      status: LIVE_STATUS_IDLE,
      requestedBy: null,
      requestedAt: null,
      respondedAt: null,
    };
  }
  return {
    roomId: row.room_id,
    status: row.status || LIVE_STATUS_IDLE,
    requestedBy: row.requested_by || null,
    requestedAt: row.requested_at || null,
    respondedAt: row.responded_at || null,
  };
}

async function upsertLiveSession(roomId, status, options = {}) {
  const requestedBy = options.requestedBy || null;
  const requestedAt = options.requestedAt || null;
  const respondedAt = options.respondedAt || null;
  await db.run(
    `INSERT INTO live_sessions (
      room_id, status, requested_by, requested_at, responded_at
    ) VALUES (?, ?, ?, ?, ?)
    ON CONFLICT(room_id) DO UPDATE SET
      status = excluded.status,
      requested_by = excluded.requested_by,
      requested_at = excluded.requested_at,
      responded_at = excluded.responded_at`,
    roomId,
    status,
    requestedBy,
    requestedAt,
    respondedAt,
  );
}

async function insertLiveMessage(roomId, senderId, senderName, content, options = {}) {
  const updateRoomPreview = options.updateRoomPreview !== false;
  const messageId = uuidv4();
  const sentAt = toIsoNow();
  await db.run(
    `INSERT INTO messages (
      id, room_id, sender_id, sender_name, type, content, duration_seconds, sent_at
    ) VALUES (?, ?, ?, ?, 'live', ?, 0, ?)`,
    messageId,
    roomId,
    senderId,
    senderName,
    content,
    sentAt,
  );
  if (updateRoomPreview) {
    await db.run(
      "UPDATE rooms SET last_message = ?, last_updated_at = ? WHERE id = ?",
      roomPreviewFromMessage("live", content),
      sentAt,
      roomId,
    );
  }
  return db.get("SELECT * FROM messages WHERE id = ?", messageId);
}

const storage = multer.diskStorage({
  destination: (req, _file, cb) => {
    const folder = req.uploadFolder || "misc";
    const destination = path.join(uploadsRoot, folder);
    fs.mkdirSync(destination, { recursive: true });
    cb(null, destination);
  },
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname) || "";
    cb(null, `${Date.now()}-${uuidv4()}${ext}`);
  },
});
const upload = multer({ storage });

app.get("/api/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.post("/api/triage/analyze", requireAuth, async (req, res) => {
  const normalized = normalizeTriagePayload(req.body);
  if (normalized.error) {
    await insertTriageAuditLog({
      userId: req.authUser?.id,
      input: req.body || {},
      result: null,
      moderationFlagged: false,
      status: "invalid_input",
      errorCode: normalized.error,
      errorMessage: normalized.message,
    });
    return apiError(res, 400, normalized.error, normalized.message);
  }

  const client = getOpenAiClient();
  if (!client) {
    await insertTriageAuditLog({
      userId: req.authUser?.id,
      input: normalized,
      result: null,
      moderationFlagged: false,
      status: "unavailable",
      errorCode: "triage-openai-not-configured",
      errorMessage: "OpenAI API key is missing or SDK is unavailable.",
    });
    return apiError(
      res,
      503,
      "triage-openai-not-configured",
      "Triage AI is not configured on backend.",
    );
  }

  let moderationFlagged = false;
  if (TRIAGE_ENABLE_MODERATION) {
    try {
      const moderation = await client.moderations.create({
        model: "omni-moderation-latest",
        input: `${normalized.symptoms}\n${normalized.duration}`,
      });
      moderationFlagged = isModerationFlagged(moderation);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("triage-moderation-failed", error);
    }
  }

  if (moderationFlagged) {
    const fallback = buildModerationFallback(normalized);
    await insertTriageAuditLog({
      userId: req.authUser?.id,
      input: normalized,
      result: fallback,
      moderationFlagged: true,
      status: "moderation_flagged",
      errorCode: "triage-content-flagged",
      errorMessage: "Content flagged by moderation.",
    });
    return res.json(fallback);
  }

  const systemPrompt = `
أنت مساعد فرز طبي (Triage) غير تشخيصي.
- لا تقدّم تشخيصًا نهائيًا.
- لا تقدّم أي جرعات دوائية أو وصفات دوائية.
- ركّز فقط على: مستوى الخطورة، مؤشرات الإنذار، أسئلة متابعة، نصائح سلامة عامة.
- إذا وجدت مؤشرات خطر، ارفع مستوى الخطورة واذكر ضرورة التوجه للطوارئ فورًا.
- استخدم لغة المستخدم (ar أو fr).
- يجب أن تكون suggested_specialty واحدة من: general_practice, pediatrics, gynecology, emergency.
- أعد JSON فقط حسب المخطط المطلوب.
  `.trim();

  const userPayload = {
    age: normalized.age,
    sex: normalized.sex,
    weightKg: normalized.weightKg,
    pregnant: normalized.pregnant,
    symptoms: normalized.symptoms,
    duration: normalized.duration,
    locale: normalized.language,
    country: "TD",
  };

  try {
    const response = await requestStructuredTriageResponse(client, [
      { role: "system", content: systemPrompt },
      { role: "user", content: JSON.stringify(userPayload) },
    ]);
    const parsed = extractTriageResponseObject(response);
    const result = normalizeTriageResult(parsed, normalized);

    await insertTriageAuditLog({
      userId: req.authUser?.id,
      input: normalized,
      result,
      moderationFlagged,
      status: "success",
    });

    return res.json(result);
  } catch (error) {
    const details = String(error?.message || "triage_failed").slice(0, 500);
    const fallback = normalizeTriageResult(buildAiUnavailableFallback(normalized), normalized);
    await insertTriageAuditLog({
      userId: req.authUser?.id,
      input: normalized,
      result: fallback,
      moderationFlagged,
      status: "fallback_ai_error",
      errorCode: "triage-fallback",
      errorMessage: details,
    });
    return res.json(fallback);
  }
});

app.post("/api/auth/signup", async (req, res) => {
  try {
    const name = String(req.body.name || "").trim();
    const password = String(req.body.password || "");
    const role = req.body.role === "doctor" ? "doctor" : "patient";
    const phoneNumber = toDisplayPhone(req.body.phoneNumber);

    if (name.length < 3) {
      return apiError(res, 400, "invalid-name", "Name must be at least 3 characters.");
    }
    if (password.length < 6) {
      return apiError(res, 400, "weak-password", "Password must be at least 6 characters.");
    }

    const exists = await db.get(
      "SELECT id FROM users WHERE phone_number = ?",
      phoneNumber,
    );
    if (exists) {
      return apiError(res, 409, "phone-already-in-use", "Phone number already used.");
    }

    const id = uuidv4();
    const createdAt = toIsoNow();
    const hash = await bcrypt.hash(password, 12);

    await db.run(
      `INSERT INTO users (
        id, name, phone_number, password_hash, role, photo_url, specialty,
        hospital_name, experience_years, study_years, created_at
      ) VALUES (?, ?, ?, ?, ?, '', '', '', 0, 0, ?)`,
      id,
      name,
      phoneNumber,
      hash,
      role,
      createdAt,
    );

    const userRow = await db.get("SELECT * FROM users WHERE id = ?", id);
    const user = mapUserRow(userRow);
    return res.status(201).json({ token: issueToken(user), user });
  } catch (error) {
    if (error.message === "invalid-phone-number") {
      return apiError(res, 400, "invalid-phone-number", "Invalid phone number.");
    }
    return apiError(res, 500, "signup-failed", "Unable to create account.");
  }
});

app.post("/api/auth/signin", async (req, res) => {
  try {
    const phoneNumber = toDisplayPhone(req.body.phoneNumber);
    const password = String(req.body.password || "");

    const row = await db.get(
      "SELECT * FROM users WHERE phone_number = ?",
      phoneNumber,
    );
    if (!row) {
      return apiError(res, 401, "invalid-credential", "Invalid credentials.");
    }
    if (row.is_disabled === 1) {
      return apiError(res, 403, "account-disabled", "This account has been disabled.");
    }

    const isValid = await bcrypt.compare(password, row.password_hash);
    if (!isValid) {
      return apiError(res, 401, "invalid-credential", "Invalid credentials.");
    }

    const user = mapUserRow(row);
    return res.json({ token: issueToken(user), user });
  } catch (error) {
    if (error.message === "invalid-phone-number") {
      return apiError(res, 400, "invalid-phone-number", "Invalid phone number.");
    }
    return apiError(res, 500, "signin-failed", "Unable to sign in.");
  }
});

app.get("/api/auth/me", requireAuth, async (req, res) => {
  res.json({ user: req.authUser });
});

app.post("/api/auth/logout", requireAuth, async (_req, res) => {
  res.status(204).send();
});

app.post("/api/auth/change-password", requireAuth, async (req, res) => {
  const currentPassword = String(req.body.currentPassword || "");
  const newPassword = String(req.body.newPassword || "");

  if (newPassword.length < 8) {
    return apiError(res, 400, "weak-password", "New password must be at least 8 characters.");
  }

  const row = await db.get("SELECT * FROM users WHERE id = ?", req.authUser.id);
  const isValid = await bcrypt.compare(currentPassword, row.password_hash);
  if (!isValid) {
    return apiError(res, 400, "wrong-password", "Current password is incorrect.");
  }

  const newHash = await bcrypt.hash(newPassword, 12);
  await db.run("UPDATE users SET password_hash = ? WHERE id = ?", newHash, req.authUser.id);
  return res.status(204).send();
});

app.get("/api/doctors", requireAuth, async (_req, res) => {
  const rows = await db.all(
    "SELECT * FROM users WHERE role = 'doctor' AND is_disabled = 0 ORDER BY created_at DESC",
  );
  res.json({ doctors: rows.map(mapUserRow) });
});

app.get("/api/admin/users", requireAuth, requireAdmin, async (_req, res) => {
  const rows = await db.all(
    `SELECT
       u.*,
       p.last_seen_at
     FROM users u
      LEFT JOIN app_presence p ON p.user_id = u.id
      ORDER BY datetime(created_at) DESC`,
  );
  return res.json({ users: rows.map(mapUserRow) });
});

app.get("/api/admin/dashboard", requireAuth, requireAdmin, async (_req, res) => {
  const boundaries = getUtcDateBoundaries();
  const onlineThresholdIso = new Date(Date.now() - APP_ONLINE_WINDOW_MS).toISOString();

  const totals = await db.get(
    `SELECT
       COUNT(1) AS total_users,
       SUM(CASE WHEN role = 'doctor' THEN 1 ELSE 0 END) AS doctors_count,
       SUM(CASE WHEN role = 'patient' THEN 1 ELSE 0 END) AS patients_count,
       SUM(CASE WHEN is_disabled = 1 THEN 1 ELSE 0 END) AS disabled_users_count
     FROM users
     WHERE phone_number != ?`,
    ADMIN_DISPLAY_PHONE,
  );

  const visitorsToday = await db.get(
    `SELECT COUNT(DISTINCT a.user_id) AS count
     FROM user_daily_activity a
     JOIN users u ON u.id = a.user_id
     WHERE a.activity_date = ?
       AND u.phone_number != ?`,
    boundaries.dayDate,
    ADMIN_DISPLAY_PHONE,
  );
  const visitorsMonth = await db.get(
    `SELECT COUNT(DISTINCT a.user_id) AS count
     FROM user_daily_activity a
     JOIN users u ON u.id = a.user_id
     WHERE a.activity_date >= ?
       AND u.phone_number != ?`,
    boundaries.monthDate,
    ADMIN_DISPLAY_PHONE,
  );
  const visitorsYear = await db.get(
    `SELECT COUNT(DISTINCT a.user_id) AS count
     FROM user_daily_activity a
     JOIN users u ON u.id = a.user_id
     WHERE a.activity_date >= ?
       AND u.phone_number != ?`,
    boundaries.yearDate,
    ADMIN_DISPLAY_PHONE,
  );
  const visitorsCurrent = await db.get(
    `SELECT COUNT(1) AS count
     FROM app_presence p
     JOIN users u ON u.id = p.user_id
     WHERE datetime(p.last_seen_at) >= datetime(?)
       AND u.phone_number != ?
       AND u.is_disabled = 0`,
    onlineThresholdIso,
    ADMIN_DISPLAY_PHONE,
  );

  const doctorStatsRows = await db.all(
    `SELECT
       u.id,
       u.name,
       u.phone_number,
       u.photo_url,
       u.specialty,
       u.hospital_name,
       u.is_disabled,
       (
         SELECT COUNT(DISTINCT r.patient_id)
         FROM rooms r
         WHERE r.doctor_id = u.id
           AND datetime(r.created_at) >= datetime(?)
       ) AS patients_today,
       (
         SELECT COUNT(DISTINCT r.patient_id)
         FROM rooms r
         WHERE r.doctor_id = u.id
           AND datetime(r.created_at) >= datetime(?)
       ) AS patients_month,
       (
         SELECT COUNT(DISTINCT r.patient_id)
         FROM rooms r
         WHERE r.doctor_id = u.id
           AND datetime(r.created_at) >= datetime(?)
       ) AS patients_year,
       (
         SELECT COUNT(1)
         FROM rooms r
         WHERE r.doctor_id = u.id
           AND datetime(r.created_at) >= datetime(?)
       ) AS consultations_today,
       (
         SELECT COUNT(1)
         FROM rooms r
         WHERE r.doctor_id = u.id
           AND datetime(r.created_at) >= datetime(?)
       ) AS consultations_month,
       (
         SELECT COUNT(1)
         FROM rooms r
         WHERE r.doctor_id = u.id
           AND datetime(r.created_at) >= datetime(?)
       ) AS consultations_year
     FROM users u
     WHERE u.role = 'doctor'
       AND u.phone_number != ?
     ORDER BY patients_year DESC, patients_month DESC, patients_today DESC, datetime(u.created_at) DESC`,
    boundaries.dayStartIso,
    boundaries.monthStartIso,
    boundaries.yearStartIso,
    boundaries.dayStartIso,
    boundaries.monthStartIso,
    boundaries.yearStartIso,
    ADMIN_DISPLAY_PHONE,
  );

  const currentVisitorsRows = await db.all(
    `SELECT
       u.id,
       u.name,
       u.phone_number,
       u.role,
       u.photo_url,
       u.is_disabled,
       p.last_seen_at
     FROM app_presence p
     JOIN users u ON u.id = p.user_id
     WHERE datetime(p.last_seen_at) >= datetime(?)
       AND u.phone_number != ?
     ORDER BY datetime(p.last_seen_at) DESC
     LIMIT 100`,
    onlineThresholdIso,
    ADMIN_DISPLAY_PHONE,
  );

  const doctors = doctorStatsRows.map((row) => ({
    id: row.id,
    name: row.name,
    phoneNumber: row.phone_number,
    photoUrl: row.photo_url || "",
    specialty: row.specialty || "",
    hospitalName: row.hospital_name || "",
    isDisabled: row.is_disabled === 1,
    patientsToday: Number(row.patients_today || 0),
    patientsMonth: Number(row.patients_month || 0),
    patientsYear: Number(row.patients_year || 0),
    consultationsToday: Number(row.consultations_today || 0),
    consultationsMonth: Number(row.consultations_month || 0),
    consultationsYear: Number(row.consultations_year || 0),
  }));

  const currentVisitors = currentVisitorsRows.map((row) => ({
    id: row.id,
    name: row.name,
    phoneNumber: row.phone_number,
    role: row.role,
    photoUrl: row.photo_url || "",
    isDisabled: row.is_disabled === 1,
    lastSeenAt: row.last_seen_at,
  }));

  return res.json({
    summary: {
      totalUsers: Number(totals?.total_users || 0),
      doctorsCount: Number(totals?.doctors_count || 0),
      patientsCount: Number(totals?.patients_count || 0),
      disabledUsersCount: Number(totals?.disabled_users_count || 0),
    },
    visitors: {
      today: Number(visitorsToday?.count || 0),
      month: Number(visitorsMonth?.count || 0),
      year: Number(visitorsYear?.count || 0),
      currentOnline: Number(visitorsCurrent?.count || 0),
    },
    doctors,
    currentVisitors,
  });
});

app.post("/api/admin/users", requireAuth, requireAdmin, async (req, res) => {
  try {
    const name = String(req.body.name || "").trim();
    const password = String(req.body.password || "");
    const role = req.body.role === "doctor" ? "doctor" : "patient";
    const phoneNumber = toDisplayPhone(req.body.phoneNumber);

    const specialty = String(req.body.specialty || "").trim();
    const hospitalName = String(req.body.hospitalName || "").trim();
    const experienceYears = Math.max(0, Math.floor(Number(req.body.experienceYears || 0)));
    const studyYears = Math.max(0, Math.floor(Number(req.body.studyYears || 0)));

    if (name.length < 3) {
      return apiError(res, 400, "invalid-name", "Name must be at least 3 characters.");
    }
    if (password.length < 4) {
      return apiError(res, 400, "weak-password", "Password must be at least 4 characters.");
    }
    if (phoneNumber === ADMIN_DISPLAY_PHONE) {
      return apiError(res, 409, "reserved-phone", "This phone number is reserved for admin.");
    }

    const exists = await db.get(
      "SELECT id FROM users WHERE phone_number = ?",
      phoneNumber,
    );
    if (exists) {
      return apiError(res, 409, "phone-already-in-use", "Phone number already used.");
    }

    const id = uuidv4();
    const createdAt = toIsoNow();
    const hash = await bcrypt.hash(password, 12);

    await db.run(
      `INSERT INTO users (
        id, name, phone_number, password_hash, role, photo_url, specialty,
        hospital_name, experience_years, study_years, created_at
      ) VALUES (?, ?, ?, ?, ?, '', ?, ?, ?, ?, ?)`,
      id,
      name,
      phoneNumber,
      hash,
      role,
      role === "doctor" ? specialty : "",
      role === "doctor" ? hospitalName : "",
      role === "doctor" ? experienceYears : 0,
      role === "doctor" ? studyYears : 0,
      createdAt,
    );

    const userRow = await db.get("SELECT * FROM users WHERE id = ?", id);
    return res.status(201).json({ user: mapUserRow(userRow) });
  } catch (error) {
    if (error.message === "invalid-phone-number") {
      return apiError(res, 400, "invalid-phone-number", "Invalid phone number.");
    }
    return apiError(res, 500, "admin-create-user-failed", "Unable to create user.");
  }
});

app.patch("/api/admin/users/:userId/status", requireAuth, requireAdmin, async (req, res) => {
  const userId = String(req.params.userId || "").trim();
  if (!userId) {
    return apiError(res, 400, "user-id-required", "userId is required.");
  }

  const user = await db.get("SELECT * FROM users WHERE id = ?", userId);
  if (!user) {
    return apiError(res, 404, "user-not-found", "User not found.");
  }
  if (user.phone_number === ADMIN_DISPLAY_PHONE) {
    return apiError(res, 403, "cannot-disable-admin", "Admin account cannot be disabled.");
  }
  if (user.id === req.authUser.id) {
    return apiError(res, 403, "cannot-disable-self", "You cannot disable your own account.");
  }

  const disabled = Boolean(req.body.disabled);
  await db.run(
    `UPDATE users
     SET is_disabled = ?, disabled_at = ?
     WHERE id = ?`,
    disabled ? 1 : 0,
    disabled ? toIsoNow() : null,
    userId,
  );

  const updated = await db.get(
    `SELECT
       u.*,
       p.last_seen_at
     FROM users u
     LEFT JOIN app_presence p ON p.user_id = u.id
     WHERE u.id = ?`,
    userId,
  );
  return res.json({ user: mapUserRow(updated) });
});

app.post("/api/admin/users/:userId/reset-password", requireAuth, requireAdmin, async (req, res) => {
  const userId = String(req.params.userId || "").trim();
  const newPassword = String(req.body.newPassword || "");

  if (!userId) {
    return apiError(res, 400, "user-id-required", "userId is required.");
  }
  if (newPassword.length < 4) {
    return apiError(res, 400, "weak-password", "Password must be at least 4 characters.");
  }

  const user = await db.get("SELECT id FROM users WHERE id = ?", userId);
  if (!user) {
    return apiError(res, 404, "user-not-found", "User not found.");
  }

  const hash = await bcrypt.hash(newPassword, 12);
  await db.run(
    "UPDATE users SET password_hash = ? WHERE id = ?",
    hash,
    userId,
  );
  return res.status(204).send();
});

app.delete("/api/admin/users/:userId", requireAuth, requireAdmin, async (req, res) => {
  const userId = String(req.params.userId || "").trim();
  if (!userId) {
    return apiError(res, 400, "user-id-required", "userId is required.");
  }
  if (userId === req.authUser.id) {
    return apiError(res, 403, "cannot-delete-self", "Admin cannot delete own account.");
  }

  const user = await db.get("SELECT * FROM users WHERE id = ?", userId);
  if (!user) {
    return apiError(res, 404, "user-not-found", "User not found.");
  }
  if (user.phone_number === ADMIN_DISPLAY_PHONE) {
    return apiError(res, 403, "cannot-delete-admin", "Cannot delete the main admin account.");
  }

  await db.run("DELETE FROM messages WHERE sender_id = ?", userId);
  await db.run("DELETE FROM room_presence WHERE user_id = ?", userId);
  await db.run("DELETE FROM consultation_requests WHERE patient_id = ? OR target_doctor_id = ?", userId, userId);
  await db.run("DELETE FROM rooms WHERE patient_id = ? OR doctor_id = ?", userId, userId);
  await db.run("DELETE FROM blogs WHERE author_id = ?", userId);
  await db.run("DELETE FROM users WHERE id = ?", userId);

  return res.status(204).send();
});

app.put("/api/users/me/doctor-profile", requireAuth, async (req, res) => {
  if (req.authUser.role !== "doctor") {
    return apiError(res, 403, "forbidden", "Only doctors can update this profile.");
  }

  const specialty = String(req.body.specialty || "").trim();
  const hospitalName = String(req.body.hospitalName || "").trim();
  const experienceYears = Number(req.body.experienceYears || 0);
  const studyYears = Number(req.body.studyYears || 0);

  if (!specialty || !hospitalName) {
    return apiError(
      res,
      400,
      "doctor-profile-required-fields",
      "Specialty and hospital name are required.",
    );
  }
  if (experienceYears < 0 || studyYears < 0) {
    return apiError(res, 400, "doctor-profile-invalid-years", "Years must be zero or positive.");
  }

  await db.run(
    `UPDATE users
       SET specialty = ?, hospital_name = ?, experience_years = ?, study_years = ?
     WHERE id = ?`,
    specialty,
    hospitalName,
    Math.floor(experienceYears),
    Math.floor(studyYears),
    req.authUser.id,
  );

  const user = mapUserRow(await db.get("SELECT * FROM users WHERE id = ?", req.authUser.id));
  return res.json({ user });
});

app.post(
  "/api/users/me/photo",
  requireAuth,
  (req, _res, next) => {
    req.uploadFolder = path.join("profile_photos", req.authUser.id);
    next();
  },
  upload.single("photo"),
  async (req, res) => {
    if (!req.file) {
      return apiError(res, 400, "invalid-photo-file", "Photo file is required.");
    }

    const relativePath = path.relative(uploadsRoot, req.file.path);
    const photoUrl = buildFileUrl(req, path.join("uploads", relativePath));

    await db.run("UPDATE users SET photo_url = ? WHERE id = ?", photoUrl, req.authUser.id);

    const user = mapUserRow(await db.get("SELECT * FROM users WHERE id = ?", req.authUser.id));
    return res.json({ user });
  },
);

app.post("/api/rooms/create-or-get", requireAuth, async (req, res) => {
  if (req.authUser.role !== "patient") {
    return apiError(res, 403, "forbidden", "Only patients can start consultations.");
  }

  const doctorId = String(req.body.doctorId || "").trim();
  if (!doctorId) {
    return apiError(res, 400, "doctor-required", "doctorId is required.");
  }

  const doctor = await db.get("SELECT * FROM users WHERE id = ?", doctorId);
  if (!doctor || doctor.role !== "doctor") {
    return apiError(res, 404, "doctor-not-found", "Doctor not found.");
  }

  const patient = await db.get("SELECT * FROM users WHERE id = ?", req.authUser.id);
  if (!patient) {
    return apiError(res, 401, "unauthorized", "Invalid session.");
  }

  const room = await createOrGetRoomForUsers(patient, doctor);
  return res.status(201).json({ room: mapRoomRow(room) });
});

app.get("/api/rooms/with-doctor/:doctorId", requireAuth, async (req, res) => {
  if (req.authUser.role !== "patient") {
    return apiError(res, 403, "forbidden", "Only patients can access this endpoint.");
  }
  const doctorId = String(req.params.doctorId || "").trim();
  if (!doctorId) {
    return apiError(res, 400, "doctor-required", "doctorId is required.");
  }
  const roomId = buildRoomId(req.authUser.id, doctorId);
  const room = await getRoomWithPhotos(roomId);
  return res.json({ room: mapRoomRow(room) });
});

app.get("/api/consultation-requests/mine", requireAuth, async (req, res) => {
  if (req.authUser.role !== "patient") {
    return apiError(res, 403, "forbidden", "Only patients can access this endpoint.");
  }
  const rows = await listConsultationRequestsByPatient(req.authUser.id);
  return res.json({ requests: rows.map(mapConsultationRequestRow) });
});

app.get("/api/consultation-requests/inbox", requireAuth, async (req, res) => {
  if (req.authUser.role !== "doctor") {
    return apiError(res, 403, "forbidden", "Only doctors can access this endpoint.");
  }
  const rows = await listConsultationRequestsInboxForDoctor(req.authUser.id);
  return res.json({ requests: rows.map(mapConsultationRequestRow) });
});

app.post("/api/consultation-requests", requireAuth, async (req, res) => {
  if (req.authUser.role !== "patient") {
    return apiError(res, 403, "forbidden", "Only patients can create consultation requests.");
  }
  const patient = await db.get("SELECT * FROM users WHERE id = ?", req.authUser.id);
  if (!patient) {
    return apiError(res, 401, "unauthorized", "Invalid session.");
  }

  const normalized = normalizeConsultationPayload(req.body, patient);
  if (normalized.error) {
    return apiError(res, 400, normalized.error, normalized.message);
  }

  const doctor = await db.get("SELECT * FROM users WHERE id = ?", normalized.doctorId);
  if (!doctor || doctor.role !== "doctor") {
    return apiError(res, 404, "doctor-not-found", "Doctor not found.");
  }

  const existingRoom = await getRoomWithPhotos(buildRoomId(patient.id, doctor.id));
  if (existingRoom && existingRoom.is_closed !== 1) {
    return apiError(
      res,
      409,
      "consultation-room-exists",
      "A consultation room already exists for this doctor.",
    );
  }

  const pending = await db.get(
    `SELECT id
     FROM consultation_requests
     WHERE patient_id = ?
       AND target_doctor_id = ?
       AND status = ?
     LIMIT 1`,
    patient.id,
    doctor.id,
    CONSULTATION_STATUS_PENDING,
  );
  if (pending) {
    return apiError(
      res,
      409,
      "consultation-request-pending",
      "A pending request already exists for this doctor.",
    );
  }

  const activeExisting = await db.get(
    `SELECT id, status
     FROM consultation_requests
     WHERE patient_id = ?
       AND target_doctor_id = ?
       AND status IN (?, ?)
     LIMIT 1`,
    patient.id,
    doctor.id,
    CONSULTATION_STATUS_PENDING,
    CONSULTATION_STATUS_ACCEPTED,
  );
  if (activeExisting) {
    return apiError(
      res,
      409,
      "consultation-request-exists",
      "An existing consultation with this doctor already exists.",
    );
  }

  const now = toIsoNow();
  const requestId = uuidv4();
  await db.run(
    `INSERT INTO consultation_requests (
      id, patient_id, target_doctor_id, subject_type, subject_name,
      age_years, gender, weight_kg, state_code, spoken_language, symptoms,
      status, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    requestId,
    patient.id,
    doctor.id,
    normalized.subjectType,
    normalized.subjectName,
    normalized.ageYears,
    normalized.gender,
    normalized.weightKg,
    normalized.stateCode,
    normalized.spokenLanguage,
    normalized.symptoms,
    CONSULTATION_STATUS_PENDING,
    now,
    now,
  );

  const created = await getConsultationRequestWithDetailsById(requestId);
  return res.status(201).json({ request: mapConsultationRequestRow(created) });
});

app.post("/api/consultation-requests/:requestId/accept", requireAuth, async (req, res) => {
  if (req.authUser.role !== "doctor") {
    return apiError(res, 403, "forbidden", "Only doctors can accept consultation requests.");
  }
  const requestRow = await getConsultationRequestWithDetailsById(req.params.requestId);
  if (!requestRow) {
    return apiError(res, 404, "consultation-request-not-found", "Consultation request not found.");
  }
  if (requestRow.target_doctor_id !== req.authUser.id) {
    return apiError(res, 403, "forbidden", "No access to this consultation request.");
  }
  if (requestRow.status !== CONSULTATION_STATUS_PENDING) {
    return apiError(
      res,
      409,
      "consultation-request-not-pending",
      "Consultation request is not pending.",
    );
  }

  const patient = await db.get("SELECT * FROM users WHERE id = ?", requestRow.patient_id);
  const doctor = await db.get("SELECT * FROM users WHERE id = ?", req.authUser.id);
  if (!patient || !doctor) {
    return apiError(res, 404, "consultation-user-not-found", "Related user not found.");
  }

  const room = await createOrGetRoomForUsers(patient, doctor);
  const now = toIsoNow();
  await db.run(
    `UPDATE consultation_requests
     SET status = ?,
        linked_room_id = ?,
        responded_at = ?,
        responded_by_doctor_id = ?,
        updated_at = ?
     WHERE id = ?`,
    CONSULTATION_STATUS_ACCEPTED,
    room.id,
    now,
    req.authUser.id,
    now,
    requestRow.id,
  );
  await db.run(
    `UPDATE rooms
     SET is_closed = 0,
         last_updated_at = ?
     WHERE id = ?`,
    now,
    room.id,
  );

  const updated = await getConsultationRequestWithDetailsById(requestRow.id);
  return res.json({
    request: mapConsultationRequestRow(updated),
    room: mapRoomRow(room),
  });
});

app.post("/api/consultation-requests/:requestId/reject", requireAuth, async (req, res) => {
  if (req.authUser.role !== "doctor") {
    return apiError(res, 403, "forbidden", "Only doctors can reject consultation requests.");
  }
  const requestRow = await getConsultationRequestWithDetailsById(req.params.requestId);
  if (!requestRow) {
    return apiError(res, 404, "consultation-request-not-found", "Consultation request not found.");
  }
  if (requestRow.target_doctor_id !== req.authUser.id) {
    return apiError(res, 403, "forbidden", "No access to this consultation request.");
  }
  if (requestRow.status !== CONSULTATION_STATUS_PENDING) {
    return apiError(
      res,
      409,
      "consultation-request-not-pending",
      "Consultation request is not pending.",
    );
  }

  const now = toIsoNow();
  await db.run(
    `UPDATE consultation_requests
     SET status = ?,
         responded_at = ?,
         responded_by_doctor_id = ?,
         updated_at = ?
     WHERE id = ?`,
    CONSULTATION_STATUS_REJECTED,
    now,
    req.authUser.id,
    now,
    requestRow.id,
  );
  const updated = await getConsultationRequestWithDetailsById(requestRow.id);
  return res.json({ request: mapConsultationRequestRow(updated) });
});

app.post("/api/consultation-requests/:requestId/transfer", requireAuth, async (req, res) => {
  if (req.authUser.role !== "doctor") {
    return apiError(res, 403, "forbidden", "Only doctors can transfer consultation requests.");
  }
  const requestRow = await getConsultationRequestWithDetailsById(req.params.requestId);
  if (!requestRow) {
    return apiError(res, 404, "consultation-request-not-found", "Consultation request not found.");
  }
  if (requestRow.target_doctor_id !== req.authUser.id) {
    return apiError(res, 403, "forbidden", "No access to this consultation request.");
  }
  if (requestRow.status !== CONSULTATION_STATUS_PENDING) {
    return apiError(
      res,
      409,
      "consultation-request-not-pending",
      "Consultation request is not pending.",
    );
  }

  const newDoctorId = String(req.body.doctorId || "").trim();
  if (!newDoctorId) {
    return apiError(res, 400, "doctor-required", "doctorId is required.");
  }
  if (newDoctorId === req.authUser.id) {
    return apiError(
      res,
      400,
      "consultation-transfer-same-doctor",
      "Cannot transfer to the same doctor.",
    );
  }
  const newDoctor = await db.get("SELECT * FROM users WHERE id = ?", newDoctorId);
  if (!newDoctor || newDoctor.role !== "doctor") {
    return apiError(res, 404, "doctor-not-found", "Doctor not found.");
  }

  const existingPending = await db.get(
    `SELECT id
     FROM consultation_requests
     WHERE patient_id = ?
       AND target_doctor_id = ?
       AND status = ?
       AND id != ?
     LIMIT 1`,
    requestRow.patient_id,
    newDoctorId,
    CONSULTATION_STATUS_PENDING,
    requestRow.id,
  );
  if (existingPending) {
    return apiError(
      res,
      409,
      "consultation-request-pending",
      "A pending request already exists for this doctor.",
    );
  }

  const now = toIsoNow();
  await db.run(
    `UPDATE consultation_requests
     SET target_doctor_id = ?,
         transferred_by_doctor_id = ?,
         updated_at = ?
     WHERE id = ?`,
    newDoctorId,
    req.authUser.id,
    now,
    requestRow.id,
  );
  const updated = await getConsultationRequestWithDetailsById(requestRow.id);
  return res.json({ request: mapConsultationRequestRow(updated) });
});

app.get("/api/rooms/:roomId/consultation-request", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }
  const requestRow = await getConsultationRequestByRoom(room);
  if (!requestRow) {
    return res.json({ request: null });
  }
  return res.json({ request: mapConsultationRequestRow(requestRow) });
});

app.get("/api/rooms/:roomId/medical-record", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!room) {
    return apiError(res, 404, "room-not-found", "Room not found.");
  }
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }

  const record = await buildMedicalRecordPayload({
    patientId: room.patient_id,
    viewerRole: req.authUser.role,
    viewerUserId: req.authUser.id,
  });
  return res.json({ record });
});

app.put("/api/rooms/:roomId/medical-record", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!room) {
    return apiError(res, 404, "room-not-found", "Room not found.");
  }
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }
  if (req.authUser.role !== "doctor" || room.doctor_id !== req.authUser.id) {
    return apiError(res, 403, "forbidden", "Only the room doctor can update medical record.");
  }

  const hasAllergies = Object.prototype.hasOwnProperty.call(req.body, "allergies");
  const hasChronicDiseases = Object.prototype.hasOwnProperty.call(req.body, "chronicDiseases");
  const hasDiagnosis = Object.prototype.hasOwnProperty.call(req.body, "diagnosis");
  const hasPrescribedMedications = Object.prototype.hasOwnProperty.call(
    req.body,
    "prescribedMedications",
  );
  const hasSecretNotes = Object.prototype.hasOwnProperty.call(req.body, "secretNotes");
  const hasPrescriptionPdfUrl = Object.prototype.hasOwnProperty.call(
    req.body,
    "prescriptionPdfUrl",
  );

  if (
    !hasAllergies
    && !hasChronicDiseases
    && !hasDiagnosis
    && !hasPrescribedMedications
    && !hasSecretNotes
    && !hasPrescriptionPdfUrl
  ) {
    return apiError(
      res,
      400,
      "medical-record-empty-update",
      "At least one field is required.",
    );
  }

  const allergies = hasAllergies ? String(req.body.allergies || "").trim() : null;
  const chronicDiseases = hasChronicDiseases
    ? String(req.body.chronicDiseases || "").trim()
    : null;
  const diagnosis = hasDiagnosis ? String(req.body.diagnosis || "").trim() : null;
  const prescribedMedications = hasPrescribedMedications
    ? String(req.body.prescribedMedications || "").trim()
    : null;
  const secretNotes = hasSecretNotes ? String(req.body.secretNotes || "").trim() : null;
  const prescriptionPdfUrl = hasPrescriptionPdfUrl
    ? String(req.body.prescriptionPdfUrl || "").trim()
    : null;

  const tooLong = [
    { key: "allergies", value: allergies, max: 3000 },
    { key: "chronicDiseases", value: chronicDiseases, max: 3000 },
    { key: "diagnosis", value: diagnosis, max: 4000 },
    { key: "prescribedMedications", value: prescribedMedications, max: 4000 },
    { key: "secretNotes", value: secretNotes, max: 4000 },
    { key: "prescriptionPdfUrl", value: prescriptionPdfUrl, max: 2000 },
  ].find((item) => item.value != null && item.value.length > item.max);

  if (tooLong) {
    return apiError(
      res,
      400,
      "medical-record-invalid-field",
      `${tooLong.key} is too long.`,
    );
  }

  if (
    hasPrescriptionPdfUrl
    && prescriptionPdfUrl
    && !/^https?:\/\//i.test(prescriptionPdfUrl)
  ) {
    return apiError(
      res,
      400,
      "medical-record-invalid-pdf-url",
      "prescriptionPdfUrl must be a valid URL.",
    );
  }

  const now = toIsoNow();
  const patientId = room.patient_id;
  const profileRow = await getPatientMedicalRecordRow(patientId);
  const nextAllergies = hasAllergies ? allergies : (profileRow?.allergies || "");
  const nextChronicDiseases = hasChronicDiseases
    ? chronicDiseases
    : (profileRow?.chronic_diseases || "");

  if (profileRow) {
    await db.run(
      `UPDATE patient_medical_records
       SET allergies = ?,
           chronic_diseases = ?,
           updated_at = ?
       WHERE patient_id = ?`,
      nextAllergies,
      nextChronicDiseases,
      now,
      patientId,
    );
  } else {
    await db.run(
      `INSERT INTO patient_medical_records (
         patient_id, allergies, chronic_diseases, created_at, updated_at
       ) VALUES (?, ?, ?, ?, ?)`,
      patientId,
      nextAllergies,
      nextChronicDiseases,
      now,
      now,
    );
  }

  const hasEntryUpdate =
    hasDiagnosis || hasPrescribedMedications || hasSecretNotes || hasPrescriptionPdfUrl;
  if (hasEntryUpdate) {
    const existingEntry = await db.get(
      `SELECT *
       FROM medical_record_entries
       WHERE room_id = ?
         AND doctor_id = ?
       LIMIT 1`,
      room.id,
      req.authUser.id,
    );

    const nextDiagnosis = hasDiagnosis ? diagnosis : (existingEntry?.diagnosis || "");
    const nextPrescribedMedications = hasPrescribedMedications
      ? prescribedMedications
      : (existingEntry?.prescribed_medications || "");
    const nextSecretNotes = hasSecretNotes ? secretNotes : (existingEntry?.secret_notes || "");
    const nextPrescriptionPdfUrl = hasPrescriptionPdfUrl
      ? prescriptionPdfUrl
      : (existingEntry?.prescription_pdf_url || "");

    if (existingEntry) {
      await db.run(
        `UPDATE medical_record_entries
         SET diagnosis = ?,
             prescribed_medications = ?,
             secret_notes = ?,
             prescription_pdf_url = ?,
             updated_at = ?
         WHERE id = ?`,
        nextDiagnosis,
        nextPrescribedMedications,
        nextSecretNotes,
        nextPrescriptionPdfUrl,
        now,
        existingEntry.id,
      );
    } else {
      await db.run(
        `INSERT INTO medical_record_entries (
           id, patient_id, room_id, doctor_id, diagnosis, prescribed_medications,
           secret_notes, prescription_pdf_url, created_at, updated_at
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        uuidv4(),
        patientId,
        room.id,
        req.authUser.id,
        nextDiagnosis,
        nextPrescribedMedications,
        nextSecretNotes,
        nextPrescriptionPdfUrl,
        now,
        now,
      );
    }
  }

  const record = await buildMedicalRecordPayload({
    patientId,
    viewerRole: req.authUser.role,
    viewerUserId: req.authUser.id,
  });
  return res.json({ record });
});

app.put("/api/consultation-requests/:requestId", requireAuth, async (req, res) => {
  if (req.authUser.role !== "doctor") {
    return apiError(res, 403, "forbidden", "Only doctors can update consultation requests.");
  }
  const requestRow = await getConsultationRequestWithDetailsById(req.params.requestId);
  if (!requestRow) {
    return apiError(res, 404, "consultation-request-not-found", "Consultation request not found.");
  }
  if (requestRow.target_doctor_id !== req.authUser.id) {
    return apiError(res, 403, "forbidden", "No access to this consultation request.");
  }
  if (requestRow.status === CONSULTATION_STATUS_REJECTED) {
    return apiError(res, 409, "consultation-request-rejected", "Cannot update a rejected request.");
  }

  const normalized = normalizeConsultationPayload(
    {
      doctorId: requestRow.target_doctor_id,
      subjectType: req.body.subjectType ?? requestRow.subject_type,
      subjectName: req.body.subjectName ?? requestRow.subject_name,
      ageYears: req.body.ageYears ?? requestRow.age_years,
      gender: req.body.gender ?? requestRow.gender,
      weightKg: req.body.weightKg ?? requestRow.weight_kg,
      stateCode: req.body.stateCode ?? requestRow.state_code,
      spokenLanguage: req.body.spokenLanguage ?? requestRow.spoken_language,
      symptoms: req.body.symptoms ?? requestRow.symptoms,
    },
    { name: requestRow.patient_name },
  );
  if (normalized.error) {
    return apiError(res, 400, normalized.error, normalized.message);
  }

  const now = toIsoNow();
  await db.run(
    `UPDATE consultation_requests
     SET subject_type = ?, subject_name = ?, age_years = ?, gender = ?, weight_kg = ?,
         state_code = ?, spoken_language = ?, symptoms = ?, updated_at = ?
     WHERE id = ?`,
    normalized.subjectType,
    normalized.subjectName,
    normalized.ageYears,
    normalized.gender,
    normalized.weightKg,
    normalized.stateCode,
    normalized.spokenLanguage,
    normalized.symptoms,
    now,
    requestRow.id,
  );

  const updated = await getConsultationRequestWithDetailsById(requestRow.id);
  return res.json({ request: mapConsultationRequestRow(updated) });
});

app.get("/api/rooms", requireAuth, async (req, res) => {
  const rows = await listRoomsWithPhotosByUser(req.authUser.id, req.authUser.role);
  return res.json({ rooms: rows.map(mapRoomRow) });
});

app.get("/api/rooms/:roomId", requireAuth, async (req, res) => {
  const room = await getRoomWithPhotos(req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }
  return res.json({ room: mapRoomRow(room) });
});

app.post("/api/rooms/:roomId/presence", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }

  const isActive = req.body.active !== false;
  await updateRoomPresence(req.params.roomId, req.authUser.id, isActive);
  return res.status(204).send();
});

app.get("/api/rooms/:roomId/messages", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }

  const now = toIsoNow();
  await updateRoomPresence(req.params.roomId, req.authUser.id, true);
  await db.run(
    `UPDATE messages
       SET delivered_at = ?
     WHERE room_id = ?
       AND sender_id != ?
       AND delivered_at IS NULL`,
    now,
    req.params.roomId,
    req.authUser.id,
  );
  await db.run(
    `UPDATE messages
       SET read_at = ?
     WHERE room_id = ?
       AND sender_id != ?
       AND read_at IS NULL`,
    now,
    req.params.roomId,
    req.authUser.id,
  );

  const rows = await db.all(
    "SELECT * FROM messages WHERE room_id = ? ORDER BY datetime(sent_at) ASC",
    req.params.roomId,
  );
  return res.json({ messages: rows.map(mapMessageRow) });
});

app.post("/api/rooms/:roomId/messages/text", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }
  if (room.is_closed === 1 && room.patient_id === req.authUser.id) {
    return apiError(res, 403, "room-closed", "Room is closed. Please request a new consultation.");
  }

  const text = String(req.body.text || "").trim();
  if (!text) {
    return apiError(res, 400, "empty-message", "Message text is required.");
  }

  const messageId = uuidv4();
  const sentAt = toIsoNow();
  await db.run(
    `INSERT INTO messages (
      id, room_id, sender_id, sender_name, type, content, duration_seconds, sent_at
    ) VALUES (?, ?, ?, ?, 'text', ?, 0, ?)`,
    messageId,
    req.params.roomId,
    req.authUser.id,
    req.authUser.name,
    text,
    sentAt,
  );
  await db.run(
    "UPDATE rooms SET last_message = ?, last_updated_at = ? WHERE id = ?",
    text,
    sentAt,
    req.params.roomId,
  );

  const row = await db.get("SELECT * FROM messages WHERE id = ?", messageId);
  return res.status(201).json({ message: mapMessageRow(row) });
});

app.post(
  "/api/uploads/audio",
  requireAuth,
  (req, _res, next) => {
    req.uploadFolder = path.join("chat_audio", req.authUser.id);
    next();
  },
  upload.single("audio"),
  async (req, res) => {
    if (!req.file) {
      return apiError(res, 400, "audio-file-required", "Audio file is required.");
    }
    const relativePath = path.relative(uploadsRoot, req.file.path);
    const audioUrl = buildFileUrl(req, path.join("uploads", relativePath));
    return res.status(201).json({ audioUrl });
  },
);

app.post(
  "/api/uploads/image",
  requireAuth,
  (req, _res, next) => {
    req.uploadFolder = path.join("chat_images", req.authUser.id);
    next();
  },
  upload.single("image"),
  async (req, res) => {
    if (!req.file) {
      return apiError(res, 400, "image-file-required", "Image file is required.");
    }
    const relativePath = path.relative(uploadsRoot, req.file.path);
    const imageUrl = buildFileUrl(req, path.join("uploads", relativePath));
    return res.status(201).json({ imageUrl });
  },
);

app.post(
  "/api/uploads/prescription-pdf",
  requireAuth,
  (req, res, next) => {
    if (req.authUser.role !== "doctor") {
      return apiError(res, 403, "forbidden", "Only doctors can upload prescription PDF.");
    }
    req.uploadFolder = path.join("prescriptions", req.authUser.id);
    return next();
  },
  upload.single("pdf"),
  async (req, res) => {
    if (!req.file) {
      return apiError(res, 400, "prescription-pdf-required", "PDF file is required.");
    }

    const ext = path.extname(req.file.originalname || "").toLowerCase();
    const mimeType = String(req.file.mimetype || "").toLowerCase();
    const isPdf = ext === ".pdf" || mimeType.includes("pdf");
    if (!isPdf) {
      fs.unlink(req.file.path, () => {});
      return apiError(res, 400, "prescription-pdf-invalid-type", "Only PDF file is allowed.");
    }

    if (Number(req.file.size || 0) > 10 * 1024 * 1024) {
      fs.unlink(req.file.path, () => {});
      return apiError(res, 400, "prescription-pdf-too-large", "PDF file must be <= 10MB.");
    }

    const relativePath = path.relative(uploadsRoot, req.file.path);
    const pdfUrl = buildFileUrl(req, path.join("uploads", relativePath));
    return res.status(201).json({ pdfUrl });
  },
);

app.post("/api/rooms/:roomId/messages/audio", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }
  if (room.is_closed === 1 && room.patient_id === req.authUser.id) {
    return apiError(res, 403, "room-closed", "Room is closed. Please request a new consultation.");
  }

  const audioUrl = String(req.body.audioUrl || "").trim();
  const durationSeconds = Math.max(1, Math.floor(Number(req.body.durationSeconds || 1)));
  if (!audioUrl) {
    return apiError(res, 400, "audio-url-required", "audioUrl is required.");
  }

  const messageId = uuidv4();
  const sentAt = toIsoNow();
  await db.run(
    `INSERT INTO messages (
      id, room_id, sender_id, sender_name, type, content, duration_seconds, sent_at
    ) VALUES (?, ?, ?, ?, 'audio', ?, ?, ?)`,
    messageId,
    req.params.roomId,
    req.authUser.id,
    req.authUser.name,
    audioUrl,
    durationSeconds,
    sentAt,
  );
  await db.run(
    "UPDATE rooms SET last_message = ?, last_updated_at = ? WHERE id = ?",
    roomPreviewFromMessage("audio", ""),
    sentAt,
    req.params.roomId,
  );

  const row = await db.get("SELECT * FROM messages WHERE id = ?", messageId);
  return res.status(201).json({ message: mapMessageRow(row) });
});

app.post("/api/rooms/:roomId/messages/image", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }
  if (room.is_closed === 1 && room.patient_id === req.authUser.id) {
    return apiError(res, 403, "room-closed", "Room is closed. Please request a new consultation.");
  }

  const imageUrl = String(req.body.imageUrl || "").trim();
  if (!imageUrl) {
    return apiError(res, 400, "image-url-required", "imageUrl is required.");
  }

  const messageId = uuidv4();
  const sentAt = toIsoNow();
  await db.run(
    `INSERT INTO messages (
      id, room_id, sender_id, sender_name, type, content, duration_seconds, sent_at
    ) VALUES (?, ?, ?, ?, 'image', ?, 0, ?)`,
    messageId,
    req.params.roomId,
    req.authUser.id,
    req.authUser.name,
    imageUrl,
    sentAt,
  );
  await db.run(
    "UPDATE rooms SET last_message = ?, last_updated_at = ? WHERE id = ?",
    roomPreviewFromMessage("image", ""),
    sentAt,
    req.params.roomId,
  );

  const row = await db.get("SELECT * FROM messages WHERE id = ?", messageId);
  return res.status(201).json({ message: mapMessageRow(row) });
});

app.get("/api/rooms/:roomId/live/status", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }

  const session = await getLiveSession(req.params.roomId);
  return res.json({ session });
});

app.post("/api/rooms/:roomId/live/request", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }

  await updateRoomPresence(req.params.roomId, req.authUser.id, true);
  const otherOnline = await isOtherParticipantOnline(room, req.authUser.id);
  if (!otherOnline) {
    return apiError(
      res,
      409,
      "live-peer-offline",
      "The other participant must be in the chat to send a live request.",
    );
  }

  const current = await getLiveSession(req.params.roomId);
  if (current.status === LIVE_STATUS_ACTIVE) {
    return apiError(res, 409, "live-already-active", "Live conversation is already active.");
  }
  if (
    current.status === LIVE_STATUS_PENDING
    && current.requestedBy
    && current.requestedBy !== req.authUser.id
  ) {
    return apiError(res, 409, "live-request-pending-other", "There is already a pending request.");
  }

  const now = toIsoNow();
  await upsertLiveSession(req.params.roomId, LIVE_STATUS_PENDING, {
    requestedBy: req.authUser.id,
    requestedAt: now,
    respondedAt: null,
  });
  const messageRow = await insertLiveMessage(
    req.params.roomId,
    req.authUser.id,
    req.authUser.name,
    `${LIVE_MARKER_REQUEST} ${req.authUser.name}`,
  );

  const session = await getLiveSession(req.params.roomId);
  return res.status(201).json({ session, message: mapMessageRow(messageRow) });
});

app.post("/api/rooms/:roomId/live/start", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }

  await updateRoomPresence(req.params.roomId, req.authUser.id, true);
  const otherOnline = await isOtherParticipantOnline(room, req.authUser.id);
  if (!otherOnline) {
    return apiError(
      res,
      409,
      "live-peer-offline",
      "The other participant must be in the chat to send a live request.",
    );
  }

  const current = await getLiveSession(req.params.roomId);
  if (current.status === LIVE_STATUS_ACTIVE) {
    return apiError(res, 409, "live-already-active", "Live conversation is already active.");
  }

  const now = toIsoNow();
  await upsertLiveSession(req.params.roomId, LIVE_STATUS_PENDING, {
    requestedBy: req.authUser.id,
    requestedAt: now,
    respondedAt: null,
  });
  const messageRow = await insertLiveMessage(
    req.params.roomId,
    req.authUser.id,
    req.authUser.name,
    `${LIVE_MARKER_REQUEST} ${req.authUser.name}`,
  );

  const session = await getLiveSession(req.params.roomId);
  return res.status(201).json({ session, message: mapMessageRow(messageRow) });
});

app.post("/api/rooms/:roomId/live/accept", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }

  const current = await getLiveSession(req.params.roomId);
  if (current.status !== LIVE_STATUS_PENDING || !current.requestedBy) {
    return apiError(res, 409, "live-no-pending-request", "No pending live request.");
  }
  if (current.requestedBy === req.authUser.id) {
    return apiError(res, 403, "live-cannot-accept-own", "Requester cannot accept own request.");
  }

  await updateRoomPresence(req.params.roomId, req.authUser.id, true);
  const requesterOnline = await isOtherParticipantOnline(room, req.authUser.id);
  if (!requesterOnline) {
    return apiError(res, 409, "live-peer-offline", "The requester is no longer online.");
  }

  const now = toIsoNow();
  await upsertLiveSession(req.params.roomId, LIVE_STATUS_ACTIVE, {
    requestedBy: current.requestedBy,
    requestedAt: current.requestedAt || now,
    respondedAt: now,
  });
  const messageRow = await insertLiveMessage(
    req.params.roomId,
    req.authUser.id,
    req.authUser.name,
    `${LIVE_MARKER_START} ${req.authUser.name}`,
  );

  const session = await getLiveSession(req.params.roomId);
  return res.status(201).json({ session, message: mapMessageRow(messageRow) });
});

app.post("/api/rooms/:roomId/live/reject", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }

  const current = await getLiveSession(req.params.roomId);
  if (current.status !== LIVE_STATUS_PENDING || !current.requestedBy) {
    return apiError(res, 409, "live-no-pending-request", "No pending live request.");
  }
  if (current.requestedBy === req.authUser.id) {
    return apiError(res, 403, "live-cannot-reject-own", "Requester cannot reject own request.");
  }

  const now = toIsoNow();
  await upsertLiveSession(req.params.roomId, LIVE_STATUS_IDLE, {
    requestedBy: null,
    requestedAt: null,
    respondedAt: now,
  });
  const messageRow = await insertLiveMessage(
    req.params.roomId,
    req.authUser.id,
    req.authUser.name,
    `${LIVE_MARKER_REJECT} ${req.authUser.name}`,
  );

  const session = await getLiveSession(req.params.roomId);
  return res.status(201).json({ session, message: mapMessageRow(messageRow) });
});

app.post("/api/rooms/:roomId/live/stop", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }

  const now = toIsoNow();
  await upsertLiveSession(req.params.roomId, LIVE_STATUS_IDLE, {
    requestedBy: null,
    requestedAt: null,
    respondedAt: now,
  });
  const messageRow = await insertLiveMessage(
    req.params.roomId,
    req.authUser.id,
    req.authUser.name,
    `${LIVE_MARKER_STOP} ${req.authUser.name}`,
  );
  await updateRoomPresence(req.params.roomId, req.authUser.id, false);

  const session = await getLiveSession(req.params.roomId);
  return res.status(201).json({ session, message: mapMessageRow(messageRow) });
});

app.post("/api/rooms/:roomId/close", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!room) {
    return apiError(res, 404, "room-not-found", "Room not found.");
  }
  if (room.doctor_id !== req.authUser.id) {
    return apiError(res, 403, "forbidden", "Only the doctor can close this room.");
  }

  const now = toIsoNow();
  await db.run(
    `UPDATE rooms
     SET is_closed = 1,
         last_message = ?,
         last_updated_at = ?
     WHERE id = ?`,
    "[consultation closed]",
    now,
    room.id,
  );
  const updated = await getRoomWithPhotos(room.id);
  return res.json({ room: mapRoomRow(updated) });
});

app.post("/api/rooms/:roomId/live/join", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }

  const session = await getLiveSession(req.params.roomId);
  if (session.status !== LIVE_STATUS_ACTIVE) {
    return apiError(res, 409, "live-not-active", "Live conversation is not active.");
  }

  await updateRoomPresence(req.params.roomId, req.authUser.id, true);
  const otherOnline = await isOtherParticipantOnline(room, req.authUser.id);
  if (!otherOnline) {
    return apiError(res, 409, "live-peer-offline", "The other participant is offline.");
  }

  if (!isLiveKitConfigured()) {
    return apiError(
      res,
      503,
      "livekit-not-configured",
      "Call server is not configured on backend.",
    );
  }

  const roomName = buildLiveKitRoomName(req.params.roomId, session);
  const participantIdentity = String(req.authUser.id || "").trim();
  if (!participantIdentity) {
    return apiError(res, 401, "unauthorized", "Invalid user identity.");
  }

  try {
    const token = await issueLiveKitToken({
      roomName,
      identity: participantIdentity,
      name: req.authUser.name,
    });

    return res.json({
      session,
      url: LIVEKIT_URL,
      token,
      roomName,
      participantIdentity,
      audioOnly: true,
    });
  } catch (error) {
    console.error("livekit-token-issue-failed", error);
    return apiError(
      res,
      500,
      "livekit-token-failed",
      "Unable to create call access token.",
    );
  }
});

app.post("/api/rooms/:roomId/messages/live", requireAuth, async (req, res) => {
  const room = await db.get("SELECT * FROM rooms WHERE id = ?", req.params.roomId);
  if (!ensureParticipant(room, req.authUser.id)) {
    return apiError(res, 403, "forbidden", "No access to this room.");
  }
  if (room.is_closed === 1 && room.patient_id === req.authUser.id) {
    return apiError(res, 403, "room-closed", "Room is closed. Please request a new consultation.");
  }

  const content = String(req.body.content || "").trim();
  if (!content) {
    return apiError(res, 400, "live-content-required", "Live content is required.");
  }

  const session = await getLiveSession(req.params.roomId);
  if (session.status !== LIVE_STATUS_ACTIVE) {
    return apiError(res, 409, "live-not-active", "Live conversation is not active yet.");
  }

  await updateRoomPresence(req.params.roomId, req.authUser.id, true);
  const otherOnline = await isOtherParticipantOnline(room, req.authUser.id);
  if (!otherOnline) {
    return apiError(res, 409, "live-peer-offline", "The other participant is offline.");
  }

  const normalized = content.startsWith("[")
    ? content
    : `${LIVE_MARKER_SIGNAL} ${content}`;
  const messageRow = await insertLiveMessage(
    req.params.roomId,
    req.authUser.id,
    req.authUser.name,
    normalized,
    { updateRoomPreview: !normalized.startsWith(LIVE_MARKER_SIGNAL) },
  );
  return res.status(201).json({ message: mapMessageRow(messageRow) });
});
app.get("/api/blogs", requireAuth, async (_req, res) => {
  const rows = await db.all("SELECT * FROM blogs ORDER BY datetime(published_at) DESC");
  return res.json({ blogs: rows.map(mapBlogRow) });
});

app.post("/api/blogs", requireAuth, async (req, res) => {
  if (req.authUser.role !== "doctor") {
    return apiError(res, 403, "forbidden", "Only doctors can publish blogs.");
  }

  const title = String(req.body.title || "").trim();
  const content = String(req.body.content || "").trim();
  const category = String(req.body.category || "").trim();

  if (!title || !content || !category) {
    return apiError(res, 400, "blog-required-fields", "Title, content and category are required.");
  }
  if (content.length < 80) {
    return apiError(res, 400, "blog-content-too-short", "Blog content must be at least 80 characters.");
  }

  const id = uuidv4();
  const now = toIsoNow();
  await db.run(
    `INSERT INTO blogs (
      id, title, content, category, author_id, author_name, published_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    id,
    title,
    content,
    category,
    req.authUser.id,
    req.authUser.name,
    now,
    now,
  );

  const row = await db.get("SELECT * FROM blogs WHERE id = ?", id);
  return res.status(201).json({ blog: mapBlogRow(row) });
});

app.use((err, _req, res, _next) => {
  return apiError(res, 500, "server-error", err.message || "Unexpected server error.");
});

async function start() {
  db = await initDb();
  await ensureAdminAccount();
  app.listen(PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`SIHHA backend listening on port ${PORT}`);
  });
}

start().catch((error) => {
  // eslint-disable-next-line no-console
  console.error(error);
  process.exit(1);
});
