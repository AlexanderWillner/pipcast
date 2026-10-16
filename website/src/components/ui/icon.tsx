import { type SVGProps } from "react";

type BrandIconProps = { size?: number } & SVGProps<SVGSVGElement>;

export function Logo({ size = 24, ...props }: BrandIconProps) {
  return (
    <svg width={size} height={size} viewBox="234 230 556 540" fill="none" aria-hidden="true" {...props}>
      <path d="M604 306H326C304 306 288 322 288 344V678C288 700 304 716 326 716H674C696 716 712 700 712 678V420" stroke="currentColor" strokeWidth="60" strokeLinecap="round" strokeLinejoin="round" />
      <rect x="662" y="254" width="104" height="104" rx="22" fill="#5488CA" />
    </svg>
  );
}

export function AppleLogo({ size = 16, ...props }: BrandIconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
      {...props}
    >
      <path d="M16.4 12.9c0-2.3 1.9-3.4 2-3.5-1.1-1.6-2.8-1.8-3.4-1.8-1.4-.1-2.8.9-3.5.9s-1.8-.8-3-.8c-1.5 0-3 .9-3.8 2.3-1.6 2.8-.4 7 1.2 9.3.8 1.1 1.7 2.4 2.9 2.3 1.2 0 1.6-.7 3-.7s1.8.7 3 .7 2-1.1 2.8-2.2c.9-1.3 1.2-2.5 1.3-2.6-.1 0-2.4-.9-2.4-3.6Zm-2.3-6.6c.6-.8 1.1-1.9 1-3-1 0-2.1.6-2.8 1.4-.6.7-1.1 1.8-1 2.9 1.1.1 2.2-.6 2.8-1.3Z" />
    </svg>
  );
}

export function GitHubLogo({ size = 16, ...props }: BrandIconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
      {...props}
    >
      <path d="M12 2a10 10 0 0 0-3.16 19.49c.5.09.68-.22.68-.48v-1.7c-2.78.6-3.37-1.34-3.37-1.34-.45-1.16-1.11-1.47-1.11-1.47-.91-.62.07-.6.07-.6 1 .07 1.53 1.03 1.53 1.03.89 1.53 2.34 1.09 2.91.83.09-.65.35-1.09.63-1.34-2.22-.25-4.55-1.11-4.55-4.94 0-1.09.39-1.98 1.03-2.68-.1-.25-.45-1.27.1-2.65 0 0 .84-.27 2.75 1.02a9.5 9.5 0 0 1 5 0c1.91-1.29 2.75-1.02 2.75-1.02.55 1.38.2 2.4.1 2.65.64.7 1.03 1.59 1.03 2.68 0 3.84-2.34 4.68-4.57 4.93.36.31.68.92.68 1.85v2.74c0 .27.18.58.69.48A10 10 0 0 0 12 2Z" />
    </svg>
  );
}

export function SupportIcon({ size = 16, ...props }: BrandIconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 -960 960 960"
      fill="currentColor"
      aria-hidden="true"
      {...props}
    >
      <path d="M535-87q11 3 25.5 2.5T585-89l295-111q0-34-24-57t-56-23H526q-3 0-7-.5t-6-1.5l-59-21q-8-3-11-10t-1-15q2-7 10-11t16-1l45 17q4 2 6.5 2.5t7.5.5h105q19 0 33.5-13t14.5-34q0-14-8.5-27T649-412L372-515q-7-2-14-3.5t-14-1.5h-64v361l255 72ZM40-160q0 33 23.5 56.5T120-80q33 0 56.5-23.5T200-160v-280q0-33-23.5-56.5T120-520q-33 0-56.5 23.5T40-440v280Zm600-312q-15 0-29.5-5.5T584-494L474-602q-31-30-52.5-66.5T400-748q0-55 38.5-93.5T532-880q32 0 60 13.5t48 36.5q20-23 48-36.5t60-13.5q55 0 93.5 38.5T880-748q0 43-21 79.5T807-602L696-494q-12 11-26.5 16.5T640-472Z" />
    </svg>
  );
}
