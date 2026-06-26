import React from 'react';
import { Canvas, Circle, RoundedRect, Path, Rect } from '@shopify/react-native-skia';
import type { SymbolId } from '../game/types';

export const SYMBOL_SIZE = 76;
const BG = '#0d0d1e';

interface Props {
  symbol: SymbolId;
  size?: number;
}

export function SymbolCanvas({ symbol, size = SYMBOL_SIZE }: Props) {
  const s = size / SYMBOL_SIZE; // scale factor
  const C = size / 2;           // center

  return (
    <Canvas style={{ width: size, height: size }}>
      {/* Dark background tile */}
      <RoundedRect x={0} y={0} width={size} height={size} r={6 * s} color={BG} />

      {symbol === 'brain' && (
        <>
          <Circle cx={26 * s} cy={C} r={17 * s} color="#ff2d78" />
          <Circle cx={50 * s} cy={C} r={17 * s} color="#ff2d78" />
          {/* overlap seam cover */}
          <Rect x={35 * s} y={21 * s} width={6 * s} height={34 * s} color="#ff2d78" />
          {/* center groove */}
          <Rect x={37 * s} y={21 * s} width={2 * s} height={34 * s} color={BG} />
          {/* highlight */}
          <Circle cx={22 * s} cy={28 * s} r={5 * s} color="rgba(255,255,255,0.25)" />
        </>
      )}

      {symbol === 'eye' && (
        <>
          {/* Outer eye almond */}
          <Path
            path={`M ${10 * s} ${C} Q ${C} ${14 * s} ${(SYMBOL_SIZE - 10) * s} ${C} Q ${C} ${(SYMBOL_SIZE - 14) * s} ${10 * s} ${C} Z`}
            color="#00e5ff"
          />
          {/* Iris */}
          <Circle cx={C} cy={C} r={12 * s} color="#0891b2" />
          {/* Pupil */}
          <Circle cx={C} cy={C} r={6 * s} color="#020617" />
          {/* Specular highlight */}
          <Circle cx={C + 4 * s} cy={C - 4 * s} r={3 * s} color="rgba(255,255,255,0.85)" />
        </>
      )}

      {symbol === 'pill' && (
        <>
          <RoundedRect
            x={10 * s} y={24 * s}
            width={56 * s} height={28 * s}
            r={14 * s}
            color="#a855f7"
          />
          {/* Left half darker */}
          <Path
            path={`M ${10 * s} ${38 * s} Q ${10 * s} ${24 * s} ${24 * s} ${24 * s} L ${38 * s} ${24 * s} L ${38 * s} ${52 * s} L ${24 * s} ${52 * s} Q ${10 * s} ${52 * s} ${10 * s} ${38 * s} Z`}
            color="#7c3aed"
          />
          {/* Center divider */}
          <Rect x={36 * s} y={24 * s} width={4 * s} height={28 * s} color="rgba(0,0,0,0.35)" />
          {/* Shine */}
          <RoundedRect x={14 * s} y={26 * s} width={20 * s} height={6 * s} r={3 * s} color="rgba(255,255,255,0.18)" />
        </>
      )}

      {symbol === 'syringe' && (
        <>
          {/* Barrel */}
          <RoundedRect x={31 * s} y={8 * s} width={14 * s} height={44 * s} r={4 * s} color="#94a3b8" />
          {/* Liquid fill */}
          <RoundedRect x={34 * s} y={18 * s} width={8 * s} height={24 * s} r={2 * s} color="rgba(0,229,255,0.55)" />
          {/* Needle */}
          <Path
            path={`M ${31 * s} ${52 * s} L ${45 * s} ${52 * s} L ${38 * s} ${68 * s} Z`}
            color="#cbd5e1"
          />
          {/* Plunger cap */}
          <RoundedRect x={27 * s} y={5 * s} width={22 * s} height={8 * s} r={3 * s} color="#475569" />
          {/* Tick marks */}
          <Rect x={34 * s} y={22 * s} width={8 * s} height={2 * s} color="rgba(255,255,255,0.4)" />
          <Rect x={34 * s} y={30 * s} width={8 * s} height={2 * s} color="rgba(255,255,255,0.4)" />
          <Rect x={34 * s} y={38 * s} width={8 * s} height={2 * s} color="rgba(255,255,255,0.4)" />
        </>
      )}

      {symbol === 'vial' && (
        <>
          {/* Handle */}
          <RoundedRect x={32 * s} y={4 * s} width={12 * s} height={36 * s} r={4 * s} color="#64748b" />
          {/* Handle grip ridges */}
          <Rect x={32 * s} y={14 * s} width={12 * s} height={2 * s} color="rgba(255,255,255,0.2)" />
          <Rect x={32 * s} y={20 * s} width={12 * s} height={2 * s} color="rgba(255,255,255,0.2)" />
          <Rect x={32 * s} y={26 * s} width={12 * s} height={2 * s} color="rgba(255,255,255,0.2)" />
          {/* Blade */}
          <Path
            path={`M ${32 * s} ${40 * s} L ${44 * s} ${40 * s} L ${50 * s} ${64 * s} L ${32 * s} ${60 * s} Z`}
            color="#f1f5f9"
          />
          {/* Blade edge highlight */}
          <Path
            path={`M ${44 * s} ${40 * s} L ${50 * s} ${64 * s}`}
            color="rgba(255,255,255,0.6)"
            style="stroke"
            strokeWidth={2 * s}
          />
        </>
      )}

      {symbol === 'flatline' && (
        <>
          {/* EKG trace */}
          <Path
            path={`M ${6 * s} ${C} L ${24 * s} ${C} L ${28 * s} ${16 * s} L ${34 * s} ${60 * s} L ${40 * s} ${C} L ${70 * s} ${C}`}
            color="#ef4444"
            style="stroke"
            strokeWidth={3 * s}
            strokeCap="round"
            strokeJoin="round"
          />
        </>
      )}

      {symbol === 'book' && (
        <>
          {/* Book cover */}
          <RoundedRect x={10 * s} y={10 * s} width={56 * s} height={56 * s} r={4 * s} color="#d97706" />
          {/* Spine */}
          <Rect x={10 * s} y={10 * s} width={10 * s} height={56 * s} color="#92400e" />
          {/* Pages */}
          <RoundedRect x={22 * s} y={14 * s} width={40 * s} height={48 * s} r={2 * s} color="#fef3c7" />
          {/* Text lines */}
          <Rect x={26 * s} y={22 * s} width={30 * s} height={3 * s} color="#d97706" />
          <Rect x={26 * s} y={30 * s} width={24 * s} height={3 * s} color="#d97706" />
          <Rect x={26 * s} y={38 * s} width={28 * s} height={3 * s} color="#d97706" />
          <Rect x={26 * s} y={46 * s} width={20 * s} height={3 * s} color="#d97706" />
          {/* Highlight on cover */}
          <Rect x={14 * s} y={14 * s} width={4 * s} height={30 * s} color="rgba(255,255,255,0.15)" />
        </>
      )}
    </Canvas>
  );
}
