FROM node:20.18.0-slim AS builder

WORKDIR /home/perplexica

COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --network-timeout 600000

COPY tsconfig.json next.config.mjs next-env.d.ts postcss.config.js drizzle.config.ts tailwind.config.ts ./
COPY src ./src
COPY public ./public

RUN mkdir -p /home/perplexica/data
RUN yarn build

RUN yarn add --dev @vercel/ncc
RUN yarn ncc build ./src/lib/db/migrate.ts -o migrator

FROM builder as runner
WORKDIR /home/perplexica

ENV NODE_ENV production

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /home/perplexica/public ./public
RUN mkdir .next
RUN chown nextjs:nodejs .next

COPY --from=builder /home/perplexica/.next/standalone ./
COPY --from=builder /home/perplexica/data ./data
COPY drizzle ./drizzle
COPY --from=builder /home/perplexica/migrator/build ./build
COPY --from=builder /home/perplexica/.next/static ./public/_next/static
COPY --from=builder --chown=nextjs:nodejs /home/perplexica/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /home/perplexica/.next/standalone ./
COPY --from=builder /home/perplexica/migrator/index.js ./migrate.js

RUN mkdir /home/perplexica/uploads

USER nextjs

EXPOSE 3000

ENV PORT 3000
RUN chmod +x ./entrypoint.sh
CMD ["./entrypoint.sh"]
