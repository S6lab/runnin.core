import { z } from "zod";

const RecordBooleanSchema = z.record(z.string(), z.boolean());
