/** One layer of variables, most local first. `label` names it in error messages. */
export type Scope = {
  label: string;
  vars: Record<string, string>;
};
