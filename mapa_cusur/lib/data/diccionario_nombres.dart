/// Traduce IDs internos del grafo (los que usa `assets/campus_data.json`) a
/// nombres amigables para mostrar en la interfaz. Solo los nodos aquí
/// listados aparecen como opciones de origen/destino en el panel de
/// planificación; el resto son nodos estructurales o fantasma.
///
/// Esta limitación (que un lugar de interés deba tener una entrada aquí
/// para ser seleccionable) está declarada en la tesis y se conserva tal
/// cual -no es un descuido a "arreglar".
const Map<String, String> diccionarioNombres = {
  'EntradaA': 'Entrada Sur',
  'EntradaB': 'Entrada Principal',
  'EntradaC': 'Entrada Este',
  'Estacionamiento1': 'Estacionamiento 1',
  'Estacionamiento2': 'Estacionamiento 2',
  'Estacionamiento3': 'Estacionamiento 3',
  'Estacionamiento4': 'Estacionamiento 4',
  'Estacionamiento5': 'Estacionamiento 5',
  'Edificio_B': 'Edificio B',
  'Edificio_C': 'Edificio C',
  'Edificio_F': 'Edificio F',
  'Edificio_G': 'Edificio G',
  'Edificio_H': 'Edificio H',
  'Edificio_I': 'Edificio I',
  'Edificio_J': 'Edificio J',
  'Edificio_L': 'Edificio L',
  'Edificio_M': 'Edificio M',
  'Edificio_N': 'Edificio N',
  'Edificio_P': 'Edificio P',
  'Edificio_Q': 'Edificio Q',
  'Edificio_R': 'Edificio R',
  'Edificio_S': 'Edificio S',
  'Edificio_T': 'Edificio T',
  'Edificio_U': 'Edificio U',
  'Edificio_V': 'Edificio V',
  'Edificio_W': 'Edificio W',
  'Edificio_X': 'Edificio X',
  'Edificio_Y': 'Edificio Y',
  'Edificio_Z': 'Edificio Z',
  'C_Acuatico': 'Centro Acuático',
  'Gimnasio': 'Gimnasio',
  'CASA': 'C.A.S.A. (Biblioteca)',
  'Cafeteria': 'Cafetería Pequeña',
  'Cafeteria_P': 'Cafetería Principal',
  'Rectoria': 'Rectoría',
  'Veterinaria': 'Hospital Veterinario',
  'Clinica_Escuela': 'Clínica Escuela',
  'Bufete_Juridico': 'Bufete Jurídico',
  'Auditorio_Ochoa': 'Auditorio Antonio González Ochoa',
  'Auditorio_Zinser': 'Auditorio Adolfo Aguilar Zínser',
  'Auditorio_CASA': 'Auditorio C.A.S.A.',
  'Sala_de_Gobierno': 'Sala de Gobierno',
  'CMID': 'C.M.I.D.',
  'RadioUDG': 'Radio UDG',
  'Proteccion_Civil': 'Protección Civil',
  // Nodos de acceso agregados con el mapa vectorial (posición en la orilla
  // del lugar, tomada de campus_vector.json; píxeles derivados).
  'Cancha_Futbol_Central': 'Cancha de fútbol central',
  'Cancha_Futbol_Norte': 'Cancha de fútbol norte',
  'Cancha_Multiple': 'Cancha múltiple',
  'Lab_Programacion': 'Laboratorio de Programación',
  'Lab_Electronica': 'Laboratorio de Electrónica',
  'Lab_Periodismo': 'Laboratorio de Periodismo',
  'Centro_Aprendizaje_Global': 'Centro de Aprendizaje Global',
};
