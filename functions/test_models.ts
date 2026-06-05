import { GoogleGenAI } from '@google/genai';
import * as dotenv from 'dotenv';
dotenv.config();

async function test() {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.log("No API key");
    return;
  }
  const ai = new GoogleGenAI({ apiKey });
  try {
    const response = await ai.models.generateContent({
      model: 'gemini-1.5-flash',
      contents: 'hello',
    });
    console.log("gemini-1.5-flash SUCCESS");
  } catch(e) {
    console.log("gemini-1.5-flash ERROR: " + e.message);
  }
  
  try {
    const response = await ai.models.generateContent({
      model: 'gemini-1.5-flash-8b',
      contents: 'hello',
    });
    console.log("gemini-1.5-flash-8b SUCCESS");
  } catch(e) {
    console.log("gemini-1.5-flash-8b ERROR: " + e.message);
  }
}
test();
