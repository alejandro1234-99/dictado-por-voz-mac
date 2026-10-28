import AppKit
import DictadoNucleo
import SQLite3

/// Historial de dictados en SQLite, en ~/Library/Application Support/Oxidos OS.
/// Cada dictado se apunta al pulsar, antes de transcribir, y se completa al acabar.
final class Almacen {
    static let compartido: Almacen? = {
        do {
            return try Almacen()
        } catch {
            NSLog("Dictado: \(error.localizedDescription)")
            return nil
        }
    }()

    let carpeta: URL
    private var db: OpaquePointer?
    private static let transitorio = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    private static let fecha = ISO8601DateFormatter()

    var carpetaAudio: URL { carpeta.appendingPathComponent("audio", isDirectory: true) }

    private init() throws {
        let soporte = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        carpeta = soporte.appendingPathComponent("Oxidos OS", isDirectory: true)
        try FileManager.default.createDirectory(at: carpetaAudio, withIntermediateDirectories: true)
        let ruta = carpeta.appendingPathComponent("dictado.sqlite").path
        guard sqlite3_open(ruta, &db) == SQLITE_OK else {
            throw ErrorDictado.almacen("no se pudo abrir la base de datos")
        }
        guard sqlite3_exec(db, Self.esquema, nil, nil, nil) == SQLITE_OK else {
            throw ErrorDictado.almacen(String(cString: sqlite3_errmsg(db)))
        }
    }

    func crear(id: String, app: NSRunningApplication?, rutaAudio: String) {
        let ahora = Self.fecha.string(from: Date())
        ejecutar(
            "insert into dictados (id, creado, actualizado, app_bundle, app_nombre, ruta_audio) values (?, ?, ?, ?, ?, ?)",
            [id, ahora, ahora, app?.bundleIdentifier, app?.localizedName, rutaAudio]
        )
    }

    func cambiarEstado(id: String, estado: String) {
        ejecutar(
            "update dictados set estado = ?, actualizado = ? where id = ?",
            [estado, Self.fecha.string(from: Date()), id]
        )
    }

    /// `texto` es lo que dio el motor de voz; `textoLimpio`, lo que se escribió, ya con el estilo.
    func terminar(
        id: String, estado: String, texto: String?, textoLimpio: String? = nil, segundos: Double, ms: Int?, error: String?
    ) {
        let palabras = texto.map { $0.split(whereSeparator: \.isWhitespace).count }
        ejecutar(
            """
            update dictados set estado = ?, actualizado = ?, texto_crudo = ?, texto_limpio = ?, palabras = ?,
              segundos_audio = ?, ms_transcribir = ?, error = ? where id = ?
            """,
            [estado, Self.fecha.string(from: Date()), texto, textoLimpio, palabras, segundos, ms, error, id]
        )
    }

    /// Borra el dictado y su audio. Para toques sin querer y dictados sin voz.
    func borrar(id: String, rutaAudio: URL?) {
        ejecutar("delete from dictados where id = ?", [id])
        if let rutaAudio {
            try? FileManager.default.removeItem(at: rutaAudio)
        }
    }

    // MARK: - Lo que lee la ventana

    /// Los dictados que se escribieron, del más nuevo al más viejo. `buscando` filtra por el texto.
    func dictados(limite: Int? = nil, buscando: String? = nil) -> [DictadoGuardado] {
        var sql = """
            select id, creado, app_nombre, app_bundle, coalesce(texto_limpio, texto_crudo), texto_crudo,
              coalesce(palabras, 0), coalesce(segundos_audio, 0)
            from dictados where estado = 'pegado'
            """
        var valores: [Any?] = []
        if let buscando, !buscando.trimmingCharacters(in: .whitespaces).isEmpty {
            sql += " and (texto_limpio like ? or texto_crudo like ?)"
            valores += ["%\(buscando)%", "%\(buscando)%"]
        }
        sql += " order by creado desc"
        if let limite {
            sql += " limit ?"
            valores.append(limite)
        }
        return consultar(sql, valores) { fila in
            DictadoGuardado(
                id: Self.texto(fila, 0) ?? "",
                fecha: Self.texto(fila, 1).flatMap { Self.fecha.date(from: $0) } ?? Date.distantPast,
                app: Self.texto(fila, 2),
                appBundle: Self.texto(fila, 3),
                texto: Self.texto(fila, 4) ?? "",
                crudo: Self.texto(fila, 5),
                palabras: Int(sqlite3_column_int64(fila, 6)),
                segundos: sqlite3_column_double(fila, 7)
            )
        }
    }

    func registrosParaMetricas() -> [RegistroDictado] {
        consultar(
            "select creado, coalesce(palabras, 0), coalesce(segundos_audio, 0) from dictados where estado = 'pegado'", []
        ) { fila in
            RegistroDictado(
                fecha: Self.texto(fila, 0).flatMap { Self.fecha.date(from: $0) } ?? Date.distantPast,
                palabras: Int(sqlite3_column_int64(fila, 1)),
                segundosAudio: sqlite3_column_double(fila, 2)
            )
        }
    }

    /// Borra un dictado del historial, con su audio.
    func borrarDictado(id: String) {
        let ruta = consultar("select ruta_audio from dictados where id = ?", [id]) { Self.texto($0, 0) }.first ?? nil
        borrar(id: id, rutaAudio: ruta.map { URL(fileURLWithPath: $0) })
    }

    // MARK: - Diccionario

    /// En la tabla, una palabra propia va en `palabra` sin `correccion`; una corrección guarda en `palabra` cómo se oye y
    /// en `correccion` cómo se escribe.
    func diccionario() -> [EntradaDiccionario] {
        consultar("select id, palabra, correccion from palabras order by creado", []) { fila in
            let id = Self.texto(fila, 0) ?? UUID().uuidString
            let palabra = Self.texto(fila, 1) ?? ""
            if let correccion = Self.texto(fila, 2) {
                return EntradaDiccionario(id: id, palabra: correccion, seOye: palabra)
            }
            return EntradaDiccionario(id: id, palabra: palabra)
        }
    }

    func guardar(_ entrada: EntradaDiccionario) {
        let palabra = entrada.seOye ?? entrada.palabra
        let correccion: String? = entrada.seOye == nil ? nil : entrada.palabra
        ejecutar(
            "insert or replace into palabras (id, creado, palabra, correccion, origen) values (?, ?, ?, ?, 'manual')",
            [entrada.id, Self.fecha.string(from: Date()), palabra, correccion]
        )
    }

    func borrarDelDiccionario(id: String) {
        ejecutar("delete from palabras where id = ?", [id])
    }

    // MARK: - SQLite

    private func consultar<T>(_ sql: String, _ valores: [Any?], fila: (OpaquePointer) -> T) -> [T] {
        guard let sentencia = preparar(sql, valores) else { return [] }
        defer { sqlite3_finalize(sentencia) }
        var resultado: [T] = []
        while sqlite3_step(sentencia) == SQLITE_ROW {
            resultado.append(fila(sentencia))
        }
        return resultado
    }

    private static func texto(_ fila: OpaquePointer, _ columna: Int32) -> String? {
        guard let puntero = sqlite3_column_text(fila, columna) else { return nil }
        return String(cString: puntero)
    }

    private func preparar(_ sql: String, _ valores: [Any?]) -> OpaquePointer? {
        var sentencia: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &sentencia, nil) == SQLITE_OK, let sentencia else {
            NSLog("Dictado: SQL mal formado: \(String(cString: sqlite3_errmsg(db)))")
            return nil
        }
        for (indice, valor) in valores.enumerated() {
            let posicion = Int32(indice + 1)
            switch valor {
            case let texto as String: sqlite3_bind_text(sentencia, posicion, texto, -1, Self.transitorio)
            case let entero as Int: sqlite3_bind_int64(sentencia, posicion, Int64(entero))
            case let decimal as Double: sqlite3_bind_double(sentencia, posicion, decimal)
            default: sqlite3_bind_null(sentencia, posicion)
            }
        }
        return sentencia
    }

    private func ejecutar(_ sql: String, _ valores: [Any?]) {
        guard let sentencia = preparar(sql, valores) else { return }
        defer { sqlite3_finalize(sentencia) }
        if sqlite3_step(sentencia) != SQLITE_DONE {
            NSLog("Dictado: no se pudo guardar: \(String(cString: sqlite3_errmsg(db)))")
        }
    }

    // Copia de replica/schema.sql: si cambia una, cambia la otra.
    private static let esquema = """
    pragma journal_mode = wal;
    pragma foreign_keys = on;

    create table if not exists dictados (
      id text primary key,
      creado text not null,
      actualizado text not null,
      app_bundle text,
      app_nombre text,
      modo text not null default 'normal'
        check (modo in ('normal', 'programar', 'ia')),
      idioma text not null default 'es-ES',
      motor text not null default 'apple'
        check (motor in ('apple', 'whisper')),
      ruta_audio text,
      segundos_audio real,
      texto_crudo text,
      texto_limpio text,
      palabras integer,
      estado text not null default 'grabando'
        check (estado in ('grabando', 'transcribiendo', 'pegado', 'copiado', 'cancelado', 'fallido')),
      error text,
      ms_transcribir integer,
      ms_limpiar integer,
      marcado integer not null default 0 check (marcado in (0, 1))
    );
    create index if not exists dictados_creado on dictados (creado desc);
    create index if not exists dictados_estado on dictados (estado);

    create table if not exists palabras (
      id text primary key,
      creado text not null,
      palabra text not null check (length(trim(palabra)) between 1 and 60),
      correccion text check (correccion is null or length(trim(correccion)) between 1 and 60),
      origen text not null default 'manual'
        check (origen in ('manual', 'aprendida', 'importada'))
    );
    create unique index if not exists palabras_unica on palabras (lower(palabra), coalesce(lower(correccion), ''));

    create table if not exists snippets (
      id text primary key,
      creado text not null,
      disparador text not null check (length(trim(disparador)) between 1 and 60),
      texto text not null check (length(texto) between 1 and 4000)
    );
    create unique index if not exists snippets_disparador on snippets (lower(disparador));
    """
}
