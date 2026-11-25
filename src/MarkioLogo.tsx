import type { SVGProps } from 'react';

export default function MarkioLogo(props: SVGProps<SVGSVGElement>) {
  return <svg viewBox="0 0 330 56" role="img" aria-label="MARKIO" xmlns="http://www.w3.org/2000/svg" {...props}>
    <text x="2" y="45" fill="currentColor" fontFamily="Manrope, Inter, Arial, sans-serif" fontSize="52" fontWeight="800" letterSpacing="-2.8">MARKIO</text>
  </svg>;
};