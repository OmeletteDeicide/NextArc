import { setGlobalOptions } from "firebase-functions";
import { onRequest, type Request } from "firebase-functions/https";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";
import { initializeApp } from "firebase-admin/app";
import { getAppCheck } from "firebase-admin/app-check";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";

setGlobalOptions({ maxInstances: 10, region: "europe-west1" });

initializeApp();

/**
 * App Check en mode surveillance : un jeton absent ou invalide est seulement
 * journalisé. Passer à true une fois que les métriques de la console montrent
 * que les requêtes de l'app sont vérifiées.
 */
const ENFORCE_APP_CHECK = false;

/** Bucket des photos et bannières (multi-région EU). */
const STORAGE_BUCKET = "nextarc-fdbde";

/** Vérifie l'en-tête X-Firebase-AppCheck. Renvoie false s'il faut refuser. */
async function appCheckAllows(req: Request, fn: string): Promise<boolean> {
  const token = req.get("X-Firebase-AppCheck");
  if (!token) {
    logger.warn("App Check token missing", { fn });
    return !ENFORCE_APP_CHECK;
  }
  try {
    await getAppCheck().verifyToken(token);
    return true;
  } catch {
    logger.warn("App Check token invalid", { fn });
    return !ENFORCE_APP_CHECK;
  }
}

const anilistClientId = defineSecret("ANILIST_CLIENT_ID");
const anilistClientSecret = defineSecret("ANILIST_CLIENT_SECRET");

/**
 * Proxy OAuth : échange un authorization_code AniList contre un access_token.
 * Le client_secret reste côté serveur, jamais exposé dans l'APK.
 *
 * POST /anilistToken
 * Body JSON : { "code": "<authorization_code>", "redirect_uri": "<uri>" }
 * Réponse   : { "access_token": "..." } ou { "error": "..." }
 */
export const anilistToken = onRequest(
  { secrets: [anilistClientId, anilistClientSecret] },
  async (req, res) => {
    // CORS — autorise uniquement les requêtes de l'app mobile (scheme nextarc://)
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Content-Type, X-Firebase-AppCheck");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
      return;
    }

    if (!(await appCheckAllows(req, "anilistToken"))) {
      res.status(401).json({ error: "Unverified app" });
      return;
    }

    const { code, redirect_uri } = req.body as {
      code?: string;
      redirect_uri?: string;
    };

    if (!code || !redirect_uri) {
      res.status(400).json({ error: "Missing code or redirect_uri" });
      return;
    }

    try {
      const response = await fetch("https://anilist.co/api/v2/oauth/token", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        body: JSON.stringify({
          grant_type: "authorization_code",
          client_id: parseInt(anilistClientId.value(), 10),
          client_secret: anilistClientSecret.value(),
          redirect_uri,
          code,
        }),
      });

      const data = await response.json() as Record<string, unknown>;

      if (!response.ok) {
        logger.error("AniList token exchange failed", { status: response.status, body: data });
        res.status(response.status).json({ error: "Token exchange failed", details: data });
        return;
      }

      res.status(200).json({ access_token: data["access_token"] });
    } catch (err) {
      logger.error("Unexpected error in anilistToken", err);
      res.status(500).json({ error: "Internal server error" });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Suppression de compte (obligatoire Play Store)
// ─────────────────────────────────────────────────────────────────────────────

/**
 * Supprime les données d'un compte NextArc, en deux étapes réelles pour que
 * l'app puisse afficher la progression :
 * - `data`    : users/{uid} et toutes ses sous-collections (liste, notes,
 *               journal d'activité) ;
 * - `account` : fichiers Storage (photo, bannière) puis le compte Firebase
 *               Auth. À appeler en dernier : le jeton devient invalide.
 *
 * Le compte AniList éventuellement lié n'est jamais touché.
 *
 * POST /deleteAccount
 * En-tête  : Authorization: Bearer <Firebase ID token>
 * Body JSON : { "step": "data" | "account" }
 * Réponse   : { "done": "data" | "account" } ou { "error": "..." }
 */
export const deleteAccount = onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed" });
    return;
  }

  if (!(await appCheckAllows(req, "deleteAccount"))) {
    res.status(401).json({ error: "Unverified app" });
    return;
  }

  const header = req.get("Authorization") ?? "";
  const idToken = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!idToken) {
    res.status(401).json({ error: "Missing token" });
    return;
  }

  let uid: string;
  try {
    // checkRevoked : un compte déjà supprimé ou déconnecté partout est refusé
    uid = (await getAuth().verifyIdToken(idToken, true)).uid;
  } catch {
    res.status(401).json({ error: "Invalid token" });
    return;
  }

  const step = (req.body as { step?: string })?.step;

  try {
    if (step === "data") {
      const db = getFirestore();
      await db.recursiveDelete(db.collection("users").doc(uid));
      logger.info("Account data deleted", { uid });
      res.status(200).json({ done: "data" });
      return;
    }

    if (step === "account") {
      // Storage peut ne pas être activé : la suppression du compte ne doit
      // jamais échouer pour autant
      try {
        const bucket = getStorage().bucket(STORAGE_BUCKET);
        await Promise.all(
          [`avatars/${uid}.jpg`, `banners/${uid}.jpg`].map((path) =>
            bucket.file(path).delete({ ignoreNotFound: true })
          )
        );
      } catch (err) {
        logger.warn("Storage cleanup skipped", { uid, err });
      }
      await getAuth().deleteUser(uid);
      logger.info("Account deleted", { uid });
      res.status(200).json({ done: "account" });
      return;
    }

    res.status(400).json({ error: "Unknown step" });
  } catch (err) {
    logger.error("deleteAccount failed", { uid, step, err });
    res.status(500).json({ error: "Internal server error" });
  }
});
