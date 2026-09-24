# Vayavya Assessment & Evaluation Platform

A Vite + React + TypeScript teacher workspace for building C tests and general submissions. The current app is intentionally usable without credentials: it demonstrates the assessment workflow with local state while keeping Supabase and code execution behind replaceable boundaries.

## Installation

```bash
npm install
cp .env.example .env
```

## Development

```bash
npm run dev
```

The current shell opens the teacher workspace at `/teacher/dashboard`. The assessment builder includes basics, questions, editable test cases, configurable rubric criteria, and a review step. Other implemented views include submissions, students, integrity review, and settings.

## Environment variables

`VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` are public client configuration values and belong in `.env` locally or Vercel project environment settings. `OPENAI_API_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are secrets and must only be used by a server-side Vercel function or another trusted service. They are not read by the browser app.

Supabase and OpenAI are not connected in this environment because credentials were not supplied. To enable the backend integration, provide:

1. Supabase project URL and anon key, from Supabase Project Settings > API, configured as the two `VITE_*` values.
2. OpenAI API key, from the OpenAI API dashboard, configured only as `OPENAI_API_KEY` in a server-side deployment environment.

## Supabase setup

Run `supabase/migrations/202609220001_initial_schema.sql` in the Supabase SQL editor or through the Supabase CLI. It creates profiles, assessments, questions, test cases, rubrics, submissions, snapshots, activity, execution, similarity, integrity, viva, review, and audit tables, plus initial indexes and RLS policies.

Google OAuth is configured in Supabase Authentication > Providers. Set the Google client ID and secret there, and add the deployed Vercel URL plus `/auth/callback` to the provider redirect allowlist. Email/password can be enabled in the same Supabase panel.

## Vercel deployment

Import the repository into Vercel. The included `vercel.json` rewrites SPA routes to `index.html`. Use the default Vite build command (`npm run build`) and output directory (`dist`). Add the public Supabase variables to the Vercel project. Server-side secrets should be added only to server/API functions when those integrations are enabled.

## C execution architecture

`src/services/cExecutionService.ts` defines `compile`, `run`, `runTestCase`, and `runTestCases`. The shipped adapter refuses to execute code, which prevents arbitrary student C from running in the browser or on a Vercel app server. Replace it with a sandboxed WebAssembly compiler/runtime or a separately hosted execution API. Hidden test inputs and expected outputs must remain server-side, and results should be written through a trusted API.

## Integrity and known limitations

The UI and schema support evidence-oriented integrity analysis: activity events, code snapshots, similarity results, declarations, confidence, and evidence. An integrity signal is not proof of AI use. OpenAI analysis, normalized/AST similarity, viva generation, storage uploads, authentication, server-side score validation, and batched activity persistence are designed in the schema but require the Supabase/API credentials and server functions to be wired next. No OpenAI key is requested or stored by this repository.

The local demo data is not a substitute for authorization. Before production use, connect every mutation to Supabase RLS and trusted server-side validation, then test student and teacher policies with separate accounts.