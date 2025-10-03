# Temporary compatibility shim for development.
# MiniProfiler (and possivelmente outros middlewares) ainda referenciam Rack::File,
# mas no Rack 3 a constante se chama Rack::Files. Quando isso acontece, a requisição
# para /mini-profiler-resources/... quebra com NameError e o dashboard fica carregando.

if defined?(Rack::Files) && !defined?(Rack::File)
  Rack::File = Rack::Files
end
