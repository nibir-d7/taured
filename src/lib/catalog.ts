import appsData from "../../data/apps.json";
import templatesData from "../../data/templates.json";
import type { App, Template } from "@/lib/types";

export const bundledApps = appsData as unknown as App[];
export const bundledTemplates = templatesData as unknown as Template[];