import { setGlobalOptions } from "firebase-functions";
import { onRequest } from "firebase-functions/https";
import { defineSecret } from "firebase-functions/params";
import * as logger from "firebase-functions/logger";

setGlobalOptions({ maxInstances: 10, region: "europe-west1" });

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
    res.set("Access-Control-Allow-Headers", "Content-Type");

    if (req.method === "OPTIONS") {
      res.status(204).send("");
      return;
    }

    if (req.method !== "POST") {
      res.status(405).json({ error: "Method not allowed" });
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
          client_id: anilistClientId.value(),
          client_secret: anilistClientSecret.value(),
          redirect_uri,
          code,
        }),
      });

      const data = await response.json() as Record<string, unknown>;

      if (!response.ok) {
        logger.error("AniList token exchange failed", { status: response.status });
        res.status(response.status).json({ error: "Token exchange failed" });
        return;
      }

      res.status(200).json({ access_token: data["access_token"] });
    } catch (err) {
      logger.error("Unexpected error in anilistToken", err);
      res.status(500).json({ error: "Internal server error" });
    }
  }
);
