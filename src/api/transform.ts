/** Pure text transform applied to a file var's body after variable resolution. */
export type Transform = (text: string) => string;

/** Named transforms available to file vars, keyed by the name used in `transform:`. */
export type Transforms = Record<string, Transform>;
