import heapq
from math import radians, sin, cos, sqrt, atan2
import matplotlib.pyplot as plt
import matplotlib.image as mpimg
import os
import json

# Función para calcular distancia con Haversine (en km) - usada solo para el grafo
def haversine(lat1, lon1, lat2, lon2):
    R = 6371  # Radio de la Tierra en km
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = sin(dlat/2)**2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)**2
    c = 2 * atan2(sqrt(a), sqrt(1-a))
    return R * c

# Convertir distancia en km a minutos (velocidad: 4 km/h = 0.0667 km/min)
def km_a_minutos(distancia_km):
    velocidad_km_min = 0.0667  # 4 km/h en km/min
    return round(distancia_km / velocidad_km_min, 2)

# Coordenadas geográficas (latitud, longitud) - solo para calcular distancias en el grafo
coordenadas_geo = {
    'EntradaA': (19.72384, -103.46214),
    'EntradaB': (19.72381, -103.46019),
    'EntradaC': (19.72584, -103.46008),
    'Estacionamiento1': (19.726589107424715, -103.46044749604694),
    'Estacionamiento2': (19.725592838399145, -103.46012078813497),
    'Estacionamiento3': (19.725169481125384, -103.4601303572404),
    'Estacionamiento4': (19.72387034256162, -103.46167729593841),
    'Estacionamiento5': (19.72404868556043, -103.46260880082673),
    'L1': (19.72509, -103.46200),
    'L2': (19.72520, -103.46203),
    'L3': (19.725077440215593, -103.46147807486598),
    'L4': (19.72520, -103.46150),
    'L5': (19.72534, -103.46208),
    'L6': (19.72561, -103.46211),
    'L7': (19.725609488, -103.461802975), 
    'Edificio_L': (19.72522, -103.46177),  
    'C_Acuatico': (19.72406711643308, -103.46202251064514),
    'Gimnasio': (19.72435494801746, -103.46207347261216),
    'Edificio_C': (19.72530, -103.46140),
    'C1': (19.725067340916347, -103.46092956314955),
    'C2': (19.725272224, -103.4610138),
    'C3': (19.72529028, -103.461118775),
    'G1': (19.72499107, -103.462211825),
    'G2': (19.725135518, -103.462211825),
    'G3': (19.72499107, -103.462941125),
    'G4': (19.725135518, -103.462941125),
    'F1': (19.725176144, -103.462211825),
    'F2': (19.725298022, -103.462211825),
    'F3': (19.725176144, -103.462941125),
    'F4': (19.725298022, -103.462941125),
    'F5': (19.725338648, -103.46252675),
    'GF': (19.725144546, -103.462576475),
    'Edificio_G': (19.725072322, -103.46257095),
    'Edificio_F': (19.725230312, -103.46257095),
    'CASA': (19.72562303, -103.4623168),
    'F6': (19.725523722, -103.462863775),
    'F7': (19.725708796, -103.462885875),
    'Cafeteria': (19.725884842, -103.462410725),
    'Rectoria': (19.72548627696902, -103.46115796220602),
    'RB': (19.72553235715516, -103.46109570014112),
    'Edificio_B': (19.72571331, -103.461305725),
    'B1': (19.725731930902274, -103.46103760975274),
    'B2': (19.725654631809704, -103.4614285855803),
    'B3': (19.72593901, -103.461084725),
    'CR': (19.72540446801674, -103.46107764957218),
    'B4': (19.725659142, -103.4615433),
    'L8': (19.725433442, -103.461847175),
    'M1': (19.72589387, -103.461559875),
    'M2': (19.72602929, -103.461570925),
    'M3': (19.72589387, -103.4617201),
    'M4': (19.72602929, -103.4617201),
    'Edificio_M': (19.726020262, -103.4616538),
    'M5': (19.72582616, -103.46177535),
    'M6': (19.72589387, -103.461836125),
    'M7': (19.72566817, -103.462145525),
    'SP1': (19.726065456136457, -103.46266751502533),
    'SP2': (19.726984224920624, -103.46264518711268),
    'SP3': (19.726044438488085, -103.46201043645299),
    'SP4': (19.726591632234566, -103.46198976616918),
    'SP5': (19.726963207393116, -103.46199129824215),
    'SP6': (19.726047441009452, -103.46179353673008),
    'SP7': (19.726335682797846, -103.46178715732647),
    'SP8': (19.72668397426509, -103.46178715732647),
    'M8': (19.726141681457555, -103.46120323280671),
    'M9': (19.72648505496847, -103.46163238621719),
    'M10': (19.726477480560753, -103.46117909292737),
    'VT': (19.726831692514036, -103.46114431378433),
    'Veterinaria': (19.726848103693943, -103.4612757420163),
    'U1': (19.72628473923225, -103.46042861818341),
    'U2': (19.726386993829554, -103.46042727707902),
    'U3': (19.726298625662878, -103.46102809185369),
    'U4': (19.726404667457018, -103.46102138633167),
    'Edificio_U': (19.72633902254514, -103.4607169556311),
    'T1': (19.726034548387357, -103.46027275377496),
    'T2': (19.72613809633454, -103.46027085716692),
    'T3': (19.726048830866812, -103.46092518694142),
    'T4': (19.726159520039364, -103.46093466998164),
    'Edificio_T': (19.72604163810704, -103.46062037647194),
    'S1': (19.72583965321772, -103.46029046478762),
    'S2': (19.725948220127464, -103.46027973595234),
    'S3': (19.725852277280772, -103.46081081329784),
    'S4': (19.72597094342482, -103.46081349550666),
    'Edificio_S': (19.725834556877032, -103.46056132540228),
    'R1': (19.725612373196817, -103.46028237568547),
    'R2': (19.725741138776403, -103.4602877401031),
    'R3': (19.725642670989576, -103.46081613523977),
    'R4': (19.725753762847244, -103.46081345303094),
    'Edificio_R': (19.725627116488685, -103.46066412239834),
    'Cafeteria_P': (19.725315327337018, -103.46061406253673),
    'CF1': (19.725201066941082, -103.46029353577764),
    'CF2': (19.725456367400582, -103.46030301881784),
    'CF3': (19.725215349495052, -103.46067285738604),
    'CF4': (19.725440299551515, -103.46065768452169),
    'CFR': (19.72558218080112, -103.46066537866007),
    'Q1': (19.724911314578332, -103.46027533233756),
    'Q2': (19.725016094880253, -103.46027130902434),
    'Q3': (19.724923716813397, -103.46057646658947),
    'Q4': (19.725031995801253, -103.46057421112968),
    'Edificio_Q': (19.724976379448023, -103.46040557719427),
    'P1': (19.724697868999083, -103.46028609088322),
    'P2': (19.724803203136204, -103.46028040105888),
    'P3': (19.72472107822171, -103.46057058210005),
    'P4': (19.724810344431127, -103.46056868549192),
    'Edificio_P': (19.724805710275785, -103.4604467600477),
    'Ce1': (19.72450925059565, -103.46057811467588),
    'Ce2': (19.724924585204924, -103.46059420792876),
    'Ce3': (19.724523137180583, -103.46081012573842),
    'Ce4': (19.72501169171857, -103.46079671469434),
    'Clinica_Escuela': (19.724688513690108, -103.4605821379891),
    'V1': (19.72428454022715, -103.46031525822013),
    'V2': (19.724389320940038, -103.4603098938025),
    'V3': (19.724298426831602, -103.46077659813642),
    'V4': (19.724405732370762, -103.4607739159276),
    'Edificio_V': (19.724345136310443, -103.46055665701354),
    'XV': (19.724239093149592, -103.46055665701354),
    'X1': (19.724080028276386, -103.46030855269811),
    'X2': (19.72418228428448, -103.46031391711573),
    'X3': (19.72408760279774, -103.46077928034524),
    'X4': (19.724197433317155, -103.46077659813642),
    'Edificio_X': (19.724136837177845, -103.46055665701354),
    'Y1': (19.723864154262483, -103.46016237231863),
    'Y2': (19.72396767282986, -103.46015700790099),
    'Y3': (19.72387425363786, -103.46054190486603),
    'Y4': (19.72397773382102, -103.46054609536614),
    'Edificio_Y': (19.72387386015247, -103.46049054973729),
    'Z1': (19.72367768733632, -103.46033587413358),
    'Z2': (19.72378132040153, -103.46032764542687),
    'Z3': (19.723684745042167, -103.46078362092551),
    'Z4': (19.72379331341592, -103.46078630313431),
    'Edificio_Z': (19.72372956106586, -103.46054758654975),
    'Edificio_W': (19.724023705360096, -103.46014994909282),
    'Edificio_N': (19.724222241598913, -103.46014439951249),
    'Edificio_I': (19.726402879243672, -103.46013149557999),
    'Bufete_Juridico': (19.723620880557892, -103.46032653499577),
    'Auditorio_Ochoa': (19.723791407217405, -103.46064901472823),
    'Auditorio_Zinser': (19.726311731835924, -103.46119770355699),
    'Edificio_J': (19.725446316257262, -103.46095404667714),
    'Edificio_H': (19.725378759258756, -103.46080173841398),
    'Sala_de_Gobierno': (19.724754299896258, -103.46013614359325),
    'CMID': (19.72473486555909, -103.46251509526644),
    'GG': (19.724712346462503, -103.46205418334968),
    'Auditorio_CASA': (19.72535565399512, -103.46223210121427),
    'RadioUDG': (19.725521512219622, -103.46220645528233),
    'Proteccion_Civil': (19.723795126247566, -103.46091226145016),

    #'': (),
}

# Coordenadas en píxeles (x, y) - nuevas posiciones proporcionadas
coordenadas_pix = {
    'EntradaA': (177, 102),
    'EntradaB': (527, 154),
    'EntradaC': (532, 543),
    'Estacionamiento1': (440, 686),
    'Estacionamiento2': (538, 489),
    'Estacionamiento3': (538, 397),
    'Estacionamiento4': (240, 139),
    'Estacionamiento5': (74, 197),
    'L1': (175, 385),
    'L2': (175, 410),
    'L3': (278, 382),
    'L4': (278, 410),
    'L5': (165, 435),
    'L6': (166, 495),
    'L7': (238, 494),
    'Edificio_L': (220, 416), 
    'C_Acuatico': (193, 194),
    'Gimnasio': (175, 237),
    'Edificio_C': (342, 403),
    'C1': (383, 382),
    'C2': (366, 423),
    'C3': (347, 427),
    'G1': (164, 357),
    'G2': (164, 389),
    'G3': (32, 357),
    'G4': (32, 389),
    'F1': (164, 398),
    'F2': (164, 425),
    'F3': (32, 398),
    'F4': (32, 425),
    'F5': (107, 434),
    'F6': (46, 475),
    'F7': (46, 516),
    'GF': (98, 391),
    'Edificio_G': (99, 375),
    'Edificio_F': (99, 410),
    'CASA': (145, 497),
    'Cafeteria': (128, 555),
    'Rectoria': (336, 466),
    'RB': (368, 477),
    'Edificio_B': (328, 517),
    'B1': (368, 512),
    'B2': (301, 494),
    'B3': (368, 567),
    'CR': (345, 455),
    'B4': (285, 505),
    'L8': (230, 455),
    'M1': (282, 557),
    'M2': (280, 587),
    'M3': (253, 557),
    'M4': (253, 587),
    'Edificio_M': (265, 585),
    'M5': (243, 542),
    'M6': (232, 557),
    'M7': (176, 507),
    'SP1': (63, 575),
    'SP2': (63, 743),
    'SP3': (172, 575),
    'SP4': (172, 678),
    'SP5': (172, 743),
    'SP6': (217, 571),
    'SP7': (218, 627),
    'SP8': (218, 678),
    'M8': (325, 593),
    'M9': (246, 657),
    'M10': (340, 654),
    'VT': (339, 732),
    'Veterinaria': (305, 743),
    'U1': (466, 625),
    'U2': (466, 649),
    'U3': (353, 625),
    'U4': (353, 649),
    'Edificio_U': (411, 635),
    'T1': (494, 579),
    'T2': (494, 601),
    'T3': (373, 579),
    'T4': (373, 601),
    'Edificio_T': (430, 580),
    'S1': (494, 537),
    'S2': (494, 563),
    'S3': (390, 537),
    'S4': (390, 563),
    'Edificio_S': (430, 537),
    'R1': (494, 496),
    'R2': (494, 523),
    'R3': (390, 496),
    'R4': (390, 523),
    'Edificio_R': (430, 496),
    'CF1': (494, 412),
    'CF2': (494, 455),
    'CF3': (422, 412),
    'CF4': (422, 455),
    'CFR': (422, 477),
    'Cafeteria_P': (434, 433),
    'Q1': (494, 361),
    'Q2': (494, 380),
    'Q3': (440, 361),
    'Q4': (440, 380),
    'Edificio_Q': (469, 360),
    'P1': (494, 315),
    'P2': (494, 339),
    'P3': (440, 315),
    'P4': (440, 339),
    'Edificio_P': (467, 339),
    'Ce1': (425, 271),
    'Ce2': (425, 364),
    'Ce3': (398, 271),
    'Ce4': (398, 364),
    'Clinica_Escuela': (425, 309),
    'V1': (494, 237),
    'V2': (494, 262),
    'V3': (398, 237),
    'V4': (398, 262),
    'Edificio_V': (447, 250),
    'XV': (447, 230),
    'X1': (494, 198),
    'X2': (494, 220),
    'X3': (398, 198),
    'X4': (398, 220),
    'Edificio_X': (447, 206),
    'Y1': (519, 159),
    'Y2': (519, 181),
    'Y3': (451, 159),
    'Y4': (451, 181),
    'Edificio_Y': (465, 159),
    'Z1': (490, 119),
    'Z2': (490, 140),
    'Z3': (398, 119),
    'Z4': (398, 140),
    'Edificio_Z': (465, 130),
    'Edificio_W': (526, 184),
    'Edificio_N': (526, 216),
    'Edificio_I': (523, 637),
    'Bufete_Juridico': (474, 104),
    'Auditorio_Ochoa': (426, 140),
    'Auditorio_Zinser': (320, 629),
    'Edificio_J': (373, 451),
    'Edificio_H': (400, 446),
    'Sala_de_Gobierno': (525, 320),
    'CMID': (84, 314),
    'GG': (175, 303),
    'Auditorio_CASA': (132, 450),
    'RadioUDG': (144, 471),
    'Proteccion_Civil': (390, 140),
    
    
    #'': (,),
}

# Crear el grafo con conexiones específicas (distancias basadas en coordenadas geográficas)
graph = {
    'EntradaA': {
        'Estacionamiento4': km_a_minutos(haversine(*coordenadas_geo['EntradaA'], *coordenadas_geo['Estacionamiento4'])),
        'Estacionamiento5': km_a_minutos(haversine(*coordenadas_geo['EntradaA'], *coordenadas_geo['Estacionamiento5'])),
        'Gimnasio': km_a_minutos(haversine(*coordenadas_geo['EntradaA'], *coordenadas_geo['Gimnasio'])),
        'C_Acuatico': km_a_minutos(haversine(*coordenadas_geo['EntradaA'], *coordenadas_geo['C_Acuatico']))
        #'': km_a_minutos(haversine(*coordenadas_geo[''], *coordenadas_geo['']))
    },
    'EntradaB': {
        'Z2': km_a_minutos(haversine(*coordenadas_geo['EntradaB'], *coordenadas_geo['Z2'])),
        'Y1': km_a_minutos(haversine(*coordenadas_geo['EntradaB'], *coordenadas_geo['Y1'])),
        'Y3': km_a_minutos(haversine(*coordenadas_geo['EntradaB'], *coordenadas_geo['Y3']))
    },
    'EntradaC': {
        'R2': km_a_minutos(haversine(*coordenadas_geo['EntradaC'], *coordenadas_geo['R2'])),
        'S1': km_a_minutos(haversine(*coordenadas_geo['EntradaC'], *coordenadas_geo['S1'])),
        'S2': km_a_minutos(haversine(*coordenadas_geo['EntradaC'], *coordenadas_geo['S2'])),
        'T1': km_a_minutos(haversine(*coordenadas_geo['EntradaC'], *coordenadas_geo['T1'])),
        'T2': km_a_minutos(haversine(*coordenadas_geo['EntradaC'], *coordenadas_geo['T2'])),
        'Edificio_I': km_a_minutos(haversine(*coordenadas_geo['EntradaC'], *coordenadas_geo['Edificio_I'])),
    },
    'L1': {
        'L2': km_a_minutos(haversine(*coordenadas_geo['L1'], *coordenadas_geo['L2'])),
        'L3': km_a_minutos(haversine(*coordenadas_geo['L1'], *coordenadas_geo['L3'])),
        'Gimnasio': km_a_minutos(haversine(*coordenadas_geo['L1'], *coordenadas_geo['Gimnasio'])),
        'G2': km_a_minutos(haversine(*coordenadas_geo['L1'], *coordenadas_geo['G2'])),
        'G1': km_a_minutos(haversine(*coordenadas_geo['L1'], *coordenadas_geo['G1'])),
        'GG': km_a_minutos(haversine(*coordenadas_geo['L1'], *coordenadas_geo['GG'])),
    },
    'L2': {
        'L1': km_a_minutos(haversine(*coordenadas_geo['L2'], *coordenadas_geo['L1'])),
        'L4': km_a_minutos(haversine(*coordenadas_geo['L2'], *coordenadas_geo['L4'])),
        'L5': km_a_minutos(haversine(*coordenadas_geo['L2'], *coordenadas_geo['L5'])),
        'Edificio_L': km_a_minutos(haversine(*coordenadas_geo['L2'], *coordenadas_geo['Edificio_L'])),
        'F2': km_a_minutos(haversine(*coordenadas_geo['L2'], *coordenadas_geo['F2'])),
        'F1': km_a_minutos(haversine(*coordenadas_geo['L2'], *coordenadas_geo['F1']))
    },
    'L3': {
        'L1': km_a_minutos(haversine(*coordenadas_geo['L3'], *coordenadas_geo['L1'])),
        'L4': km_a_minutos(haversine(*coordenadas_geo['L3'], *coordenadas_geo['L4'])),
        'C1': km_a_minutos(haversine(*coordenadas_geo['L3'], *coordenadas_geo['C1'])),
        'GG': km_a_minutos(haversine(*coordenadas_geo['L3'], *coordenadas_geo['GG'])),
    },
    'L4': {
        'L3': km_a_minutos(haversine(*coordenadas_geo['L4'], *coordenadas_geo['L3'])),
        'L2': km_a_minutos(haversine(*coordenadas_geo['L4'], *coordenadas_geo['L2'])),
        'B2': km_a_minutos(haversine(*coordenadas_geo['L4'], *coordenadas_geo['B2'])),
        'Edificio_L': km_a_minutos(haversine(*coordenadas_geo['L4'], *coordenadas_geo['Edificio_L'])),
        'Edificio_C': km_a_minutos(haversine(*coordenadas_geo['L4'], *coordenadas_geo['Edificio_C']))
    },
    'L5': {
        'L2': km_a_minutos(haversine(*coordenadas_geo['L5'], *coordenadas_geo['L2'])),
        'L6': km_a_minutos(haversine(*coordenadas_geo['L5'], *coordenadas_geo['L6'])),
        'Edificio_L': km_a_minutos(haversine(*coordenadas_geo['L5'], *coordenadas_geo['Edificio_L'])),
        'F2': km_a_minutos(haversine(*coordenadas_geo['L5'], *coordenadas_geo['F2'])),
        'RadioUDG': km_a_minutos(haversine(*coordenadas_geo['L5'], *coordenadas_geo['RadioUDG'])),
        'Auditorio_CASA': km_a_minutos(haversine(*coordenadas_geo['L5'], *coordenadas_geo['Auditorio_CASA'])),
    },
    'L6': {
        'L5': km_a_minutos(haversine(*coordenadas_geo['L6'], *coordenadas_geo['L5'])),
        'CASA': km_a_minutos(haversine(*coordenadas_geo['L6'], *coordenadas_geo['CASA'])),
        'Cafeteria': km_a_minutos(haversine(*coordenadas_geo['L6'], *coordenadas_geo['Cafeteria'])),
        'L7': km_a_minutos(haversine(*coordenadas_geo['L6'], *coordenadas_geo['L7'])),
        'M7': km_a_minutos(haversine(*coordenadas_geo['L6'], *coordenadas_geo['M7'])),
        'RadioUDG': km_a_minutos(haversine(*coordenadas_geo['L6'], *coordenadas_geo['RadioUDG'])),
    },
    'L7': {
        'L8': km_a_minutos(haversine(*coordenadas_geo['L7'], *coordenadas_geo['L8'])),
        'B4': km_a_minutos(haversine(*coordenadas_geo['L7'], *coordenadas_geo['B4'])),
        'B2': km_a_minutos(haversine(*coordenadas_geo['L7'], *coordenadas_geo['B2'])),
        'L6': km_a_minutos(haversine(*coordenadas_geo['L7'], *coordenadas_geo['L6'])),
        'CASA': km_a_minutos(haversine(*coordenadas_geo['L7'], *coordenadas_geo['CASA'])),
        'M7': km_a_minutos(haversine(*coordenadas_geo['L7'], *coordenadas_geo['M7']))
    },
    'Edificio_L': {
        'L2': km_a_minutos(haversine(*coordenadas_geo['Edificio_L'], *coordenadas_geo['L2'])),
        'L4': km_a_minutos(haversine(*coordenadas_geo['Edificio_L'], *coordenadas_geo['L4'])),
        'L5': km_a_minutos(haversine(*coordenadas_geo['Edificio_L'], *coordenadas_geo['L5']))
    },
    'C_Acuatico': {
        'EntradaA': km_a_minutos(haversine(*coordenadas_geo['C_Acuatico'], *coordenadas_geo['EntradaA'])),
        'Gimnasio': km_a_minutos(haversine(*coordenadas_geo['C_Acuatico'], *coordenadas_geo['Gimnasio'])),
        'Estacionamiento4': km_a_minutos(haversine(*coordenadas_geo['C_Acuatico'], *coordenadas_geo['Estacionamiento4'])),
    },
    'Gimnasio': {
        'EntradaA': km_a_minutos(haversine(*coordenadas_geo['Gimnasio'], *coordenadas_geo['EntradaA'])),
        'L1': km_a_minutos(haversine(*coordenadas_geo['Gimnasio'], *coordenadas_geo['L1'])),
        'C_Acuatico': km_a_minutos(haversine(*coordenadas_geo['Gimnasio'], *coordenadas_geo['C_Acuatico'])),
        'Estacionamiento5': km_a_minutos(haversine(*coordenadas_geo['Gimnasio'], *coordenadas_geo['Estacionamiento5'])),
        'GG': km_a_minutos(haversine(*coordenadas_geo['Gimnasio'], *coordenadas_geo['GG'])),
    },
    'Edificio_C': {
        'C3': km_a_minutos(haversine(*coordenadas_geo['Edificio_C'], *coordenadas_geo['C3'])),
        'L4': km_a_minutos(haversine(*coordenadas_geo['Edificio_C'], *coordenadas_geo['L4']))
    },
    'C1': {
        'L3': km_a_minutos(haversine(*coordenadas_geo['C1'], *coordenadas_geo['L3'])),
        'C2': km_a_minutos(haversine(*coordenadas_geo['C1'], *coordenadas_geo['C2'])),
        'Ce4': km_a_minutos(haversine(*coordenadas_geo['C1'], *coordenadas_geo['Ce4']))
    },
    'C2': {
        'C1': km_a_minutos(haversine(*coordenadas_geo['C2'], *coordenadas_geo['C1'])),
        'C3': km_a_minutos(haversine(*coordenadas_geo['C2'], *coordenadas_geo['C3']))
    },
    'C3': {
        'C2': km_a_minutos(haversine(*coordenadas_geo['C3'], *coordenadas_geo['C2'])),
        'Edificio_C': km_a_minutos(haversine(*coordenadas_geo['C3'], *coordenadas_geo['Edificio_C'])),
        'CR': km_a_minutos(haversine(*coordenadas_geo['C3'], *coordenadas_geo['CR']))
    },
    'G1': {
        'G3': km_a_minutos(haversine(*coordenadas_geo['G1'], *coordenadas_geo['G3'])),
        'G2': km_a_minutos(haversine(*coordenadas_geo['G1'], *coordenadas_geo['G2'])),
        'L1': km_a_minutos(haversine(*coordenadas_geo['G1'], *coordenadas_geo['L1'])),
        'GG': km_a_minutos(haversine(*coordenadas_geo['G1'], *coordenadas_geo['GG'])),
    },
    'G2': {
        'G1': km_a_minutos(haversine(*coordenadas_geo['G2'], *coordenadas_geo['G1'])),
        'GF': km_a_minutos(haversine(*coordenadas_geo['G2'], *coordenadas_geo['GF'])),
        'F1': km_a_minutos(haversine(*coordenadas_geo['G2'], *coordenadas_geo['F1'])),
        'L2': km_a_minutos(haversine(*coordenadas_geo['G2'], *coordenadas_geo['L2'])),
        'L1': km_a_minutos(haversine(*coordenadas_geo['G2'], *coordenadas_geo['L1']))
    },
    'G3': {
        'G4': km_a_minutos(haversine(*coordenadas_geo['G3'], *coordenadas_geo['G4'])),
        'G1': km_a_minutos(haversine(*coordenadas_geo['G3'], *coordenadas_geo['G1']))
    },
    'G4': {
        'F3': km_a_minutos(haversine(*coordenadas_geo['G4'], *coordenadas_geo['F3'])),
        'G3': km_a_minutos(haversine(*coordenadas_geo['G4'], *coordenadas_geo['G3'])),
        'GF': km_a_minutos(haversine(*coordenadas_geo['G4'], *coordenadas_geo['GF']))
    },
    'GF': {
        'G2': km_a_minutos(haversine(*coordenadas_geo['GF'], *coordenadas_geo['G2'])),
        'G4': km_a_minutos(haversine(*coordenadas_geo['GF'], *coordenadas_geo['G4'])),
        'F3': km_a_minutos(haversine(*coordenadas_geo['GF'], *coordenadas_geo['F3'])),
        'Edificio_G': km_a_minutos(haversine(*coordenadas_geo['GF'], *coordenadas_geo['Edificio_G'])),
        'Edificio_F': km_a_minutos(haversine(*coordenadas_geo['GF'], *coordenadas_geo['Edificio_F']))
    },
    'F1': {
        'G2': km_a_minutos(haversine(*coordenadas_geo['F1'], *coordenadas_geo['G2'])),
        'F2': km_a_minutos(haversine(*coordenadas_geo['F1'], *coordenadas_geo['F2'])),
        'GF': km_a_minutos(haversine(*coordenadas_geo['F1'], *coordenadas_geo['GF'])),
        'L2': km_a_minutos(haversine(*coordenadas_geo['F1'], *coordenadas_geo['L2']))
    },
    'F2': {
        'F1': km_a_minutos(haversine(*coordenadas_geo['F2'], *coordenadas_geo['F1'])),
        'F4': km_a_minutos(haversine(*coordenadas_geo['F2'], *coordenadas_geo['F4'])),
        'F5': km_a_minutos(haversine(*coordenadas_geo['F2'], *coordenadas_geo['F5'])),
        'L5': km_a_minutos(haversine(*coordenadas_geo['F2'], *coordenadas_geo['L5'])),
        'L2': km_a_minutos(haversine(*coordenadas_geo['F2'], *coordenadas_geo['L2'])),
        'Auditorio_CASA': km_a_minutos(haversine(*coordenadas_geo['F2'], *coordenadas_geo['Auditorio_CASA'])),
        
    },
    'F3': {
        'G4': km_a_minutos(haversine(*coordenadas_geo['F3'], *coordenadas_geo['G4'])),
        'F4': km_a_minutos(haversine(*coordenadas_geo['F3'], *coordenadas_geo['F4'])),
        'GF': km_a_minutos(haversine(*coordenadas_geo['F3'], *coordenadas_geo['GF']))
    },
    'F4': {
        'F3': km_a_minutos(haversine(*coordenadas_geo['F4'], *coordenadas_geo['F3'])),
        'F2': km_a_minutos(haversine(*coordenadas_geo['F4'], *coordenadas_geo['F2']))
    },
    'F5': {
        'F2': km_a_minutos(haversine(*coordenadas_geo['F5'], *coordenadas_geo['F2'])),
        'F6': km_a_minutos(haversine(*coordenadas_geo['F5'], *coordenadas_geo['F6']))
    },
    'F6': {
        'F5': km_a_minutos(haversine(*coordenadas_geo['F6'], *coordenadas_geo['F5'])),
        'F7': km_a_minutos(haversine(*coordenadas_geo['F6'], *coordenadas_geo['F7']))
    },
    'F7': {
        'F6': km_a_minutos(haversine(*coordenadas_geo['F7'], *coordenadas_geo['F6'])),
        'Cafeteria': km_a_minutos(haversine(*coordenadas_geo['F7'], *coordenadas_geo['Cafeteria']))
    },
    'Cafeteria': {
        'F7': km_a_minutos(haversine(*coordenadas_geo['Cafeteria'], *coordenadas_geo['F7'])),
        'L6': km_a_minutos(haversine(*coordenadas_geo['Cafeteria'], *coordenadas_geo['L6']))
    },
    'CASA': {
        'L6': km_a_minutos(haversine(*coordenadas_geo['CASA'], *coordenadas_geo['L6'])),
        'L7': km_a_minutos(haversine(*coordenadas_geo['CASA'], *coordenadas_geo['L7'])),
        'M7': km_a_minutos(haversine(*coordenadas_geo['CASA'], *coordenadas_geo['M7']))
    },
    'Rectoria': {
        'RB': km_a_minutos(haversine(*coordenadas_geo['Rectoria'], *coordenadas_geo['RB'])),
        'Edificio_B': km_a_minutos(haversine(*coordenadas_geo['Rectoria'], *coordenadas_geo['Edificio_B'])),
        'B1': km_a_minutos(haversine(*coordenadas_geo['Rectoria'], *coordenadas_geo['B1'])),
        'B2': km_a_minutos(haversine(*coordenadas_geo['Rectoria'], *coordenadas_geo['B2'])),
        'CR': km_a_minutos(haversine(*coordenadas_geo['Rectoria'], *coordenadas_geo['CR']))
    },
    'RB': {
        'Rectoria': km_a_minutos(haversine(*coordenadas_geo['RB'], *coordenadas_geo['Rectoria'])),
        'B1': km_a_minutos(haversine(*coordenadas_geo['RB'], *coordenadas_geo['B1'])),
        'B2': km_a_minutos(haversine(*coordenadas_geo['RB'], *coordenadas_geo['B2'])),
        'CR': km_a_minutos(haversine(*coordenadas_geo['RB'], *coordenadas_geo['CR'])),
        'R3': km_a_minutos(haversine(*coordenadas_geo['RB'], *coordenadas_geo['R3'])),
        'CFR': km_a_minutos(haversine(*coordenadas_geo['RB'], *coordenadas_geo['CFR'])),
        'Edificio_J': km_a_minutos(haversine(*coordenadas_geo['RB'], *coordenadas_geo['Edificio_J'])),
    },
    'CR': {
        'Rectoria': km_a_minutos(haversine(*coordenadas_geo['CR'], *coordenadas_geo['Rectoria'])),
        'C3': km_a_minutos(haversine(*coordenadas_geo['CR'], *coordenadas_geo['C3'])),
        'RB': km_a_minutos(haversine(*coordenadas_geo['CR'], *coordenadas_geo['RB'])),
        'Edificio_J': km_a_minutos(haversine(*coordenadas_geo['CR'], *coordenadas_geo['Edificio_J'])),
    },
    'Edificio_B': {
        'Rectoria': km_a_minutos(haversine(*coordenadas_geo['Edificio_B'], *coordenadas_geo['Rectoria'])),
        'B1': km_a_minutos(haversine(*coordenadas_geo['B2'], *coordenadas_geo['B1']))
    },
    'B1': {
        'Rectoria': km_a_minutos(haversine(*coordenadas_geo['B1'], *coordenadas_geo['Rectoria'])),
        'B2': km_a_minutos(haversine(*coordenadas_geo['B2'], *coordenadas_geo['B2'])),
        'B3': km_a_minutos(haversine(*coordenadas_geo['B2'], *coordenadas_geo['B3'])),
        'Edificio_B': km_a_minutos(haversine(*coordenadas_geo['B2'], *coordenadas_geo['Edificio_B'])),
        'S3': km_a_minutos(haversine(*coordenadas_geo['B2'], *coordenadas_geo['S3'])),
        'S4': km_a_minutos(haversine(*coordenadas_geo['B2'], *coordenadas_geo['S4'])),
        'RB': km_a_minutos(haversine(*coordenadas_geo['B1'], *coordenadas_geo['RB'])),
        'R3': km_a_minutos(haversine(*coordenadas_geo['B1'], *coordenadas_geo['R3']))
    },
    'B2': {
        'Rectoria': km_a_minutos(haversine(*coordenadas_geo['B2'], *coordenadas_geo['Rectoria'])),
        'RB': km_a_minutos(haversine(*coordenadas_geo['B2'], *coordenadas_geo['RB'])),
        'L7': km_a_minutos(haversine(*coordenadas_geo['B2'], *coordenadas_geo['L7'])),
        'Edificio_B': km_a_minutos(haversine(*coordenadas_geo['B2'], *coordenadas_geo['Edificio_B']))
    },
    'B3': {
        'S3': km_a_minutos(haversine(*coordenadas_geo['B3'], *coordenadas_geo['S3'])),
        'S4': km_a_minutos(haversine(*coordenadas_geo['B3'], *coordenadas_geo['S4'])),
        'B1': km_a_minutos(haversine(*coordenadas_geo['B3'], *coordenadas_geo['B1'])),
        'M8': km_a_minutos(haversine(*coordenadas_geo['B3'], *coordenadas_geo['M8'])),
        'Auditorio_Zinser': km_a_minutos(haversine(*coordenadas_geo['B3'], *coordenadas_geo['Auditorio_Zinser'])),
    },
    'B4': {
        'B2': km_a_minutos(haversine(*coordenadas_geo['B4'], *coordenadas_geo['B2'])),
        'M5': km_a_minutos(haversine(*coordenadas_geo['B4'], *coordenadas_geo['M5'])),
        'L7': km_a_minutos(haversine(*coordenadas_geo['B4'], *coordenadas_geo['L7']))
    },
    'L8': {
        'L7': km_a_minutos(haversine(*coordenadas_geo['L8'], *coordenadas_geo['L7']))
    },
    'M1': {
        'M3': km_a_minutos(haversine(*coordenadas_geo['M1'], *coordenadas_geo['M3'])),
        'M2': km_a_minutos(haversine(*coordenadas_geo['M1'], *coordenadas_geo['M2']))
    },
    'M2': {
        'M1': km_a_minutos(haversine(*coordenadas_geo['M2'], *coordenadas_geo['M1'])),
        'M4': km_a_minutos(haversine(*coordenadas_geo['M2'], *coordenadas_geo['M4'])),
        'M8': km_a_minutos(haversine(*coordenadas_geo['M2'], *coordenadas_geo['M8'])),
        'Edificio_M': km_a_minutos(haversine(*coordenadas_geo['M2'], *coordenadas_geo['Edificio_M']))
    },
    'M3': {
        'M5': km_a_minutos(haversine(*coordenadas_geo['M3'], *coordenadas_geo['M5'])),
        'M1': km_a_minutos(haversine(*coordenadas_geo['M3'], *coordenadas_geo['M1'])),
        'M4': km_a_minutos(haversine(*coordenadas_geo['M3'], *coordenadas_geo['M4']))
    },
    'M4': {
        'M2': km_a_minutos(haversine(*coordenadas_geo['M4'], *coordenadas_geo['M2'])),
        'Edificio_M': km_a_minutos(haversine(*coordenadas_geo['M4'], *coordenadas_geo['Edificio_M'])),
        'M3': km_a_minutos(haversine(*coordenadas_geo['M4'], *coordenadas_geo['M3'])),
        'M9': km_a_minutos(haversine(*coordenadas_geo['M4'], *coordenadas_geo['M9']))
    },
    'Edificio_M': {
        'M4': km_a_minutos(haversine(*coordenadas_geo['Edificio_M'], *coordenadas_geo['M4'])),
        'M2': km_a_minutos(haversine(*coordenadas_geo['Edificio_M'], *coordenadas_geo['M2']))
    },
    'M5': {
        'B4': km_a_minutos(haversine(*coordenadas_geo['M5'], *coordenadas_geo['B4'])),
        'M6': km_a_minutos(haversine(*coordenadas_geo['M5'], *coordenadas_geo['M6'])),
        'M3': km_a_minutos(haversine(*coordenadas_geo['M5'], *coordenadas_geo['M3']))
    },
    'M6': {
        'M5': km_a_minutos(haversine(*coordenadas_geo['M6'], *coordenadas_geo['M5'])),
        'M7': km_a_minutos(haversine(*coordenadas_geo['M6'], *coordenadas_geo['M7']))
    },
    'M7': {
        'L6': km_a_minutos(haversine(*coordenadas_geo['M7'], *coordenadas_geo['L6'])),
        'CASA': km_a_minutos(haversine(*coordenadas_geo['M7'], *coordenadas_geo['CASA'])),
        'L7': km_a_minutos(haversine(*coordenadas_geo['M7'], *coordenadas_geo['L7'])),
        'M6': km_a_minutos(haversine(*coordenadas_geo['M7'], *coordenadas_geo['M6'])),
        'SP3': km_a_minutos(haversine(*coordenadas_geo['M7'], *coordenadas_geo['SP3']))
    },
    'Edificio_G': {
        'GF': km_a_minutos(haversine(*coordenadas_geo['Edificio_G'], *coordenadas_geo['GF']))
    },
    'Edificio_F': {
        'GF': km_a_minutos(haversine(*coordenadas_geo['Edificio_F'], *coordenadas_geo['GF']))
    },
    'SP1': {
        'SP2': km_a_minutos(haversine(*coordenadas_geo['SP1'], *coordenadas_geo['SP2'])),
        'Cafeteria': km_a_minutos(haversine(*coordenadas_geo['SP1'], *coordenadas_geo['Cafeteria'])),
        'SP3': km_a_minutos(haversine(*coordenadas_geo['SP1'], *coordenadas_geo['SP3']))
    },
    'SP2': {
        'SP1': km_a_minutos(haversine(*coordenadas_geo['SP2'], *coordenadas_geo['SP1'])),
        'SP5': km_a_minutos(haversine(*coordenadas_geo['SP2'], *coordenadas_geo['SP5']))
    },
    'SP3': {
        'SP1': km_a_minutos(haversine(*coordenadas_geo['SP3'], *coordenadas_geo['SP1'])),
        'Cafeteria': km_a_minutos(haversine(*coordenadas_geo['SP3'], *coordenadas_geo['Cafeteria'])),
        'SP4': km_a_minutos(haversine(*coordenadas_geo['SP3'], *coordenadas_geo['SP4'])),
        'SP6': km_a_minutos(haversine(*coordenadas_geo['SP3'], *coordenadas_geo['SP6'])),
        'M7': km_a_minutos(haversine(*coordenadas_geo['SP3'], *coordenadas_geo['M7']))
    },
    'SP4': {
        'SP3': km_a_minutos(haversine(*coordenadas_geo['SP4'], *coordenadas_geo['SP3'])),
        'SP5': km_a_minutos(haversine(*coordenadas_geo['SP4'], *coordenadas_geo['SP5'])),
        'SP8': km_a_minutos(haversine(*coordenadas_geo['SP4'], *coordenadas_geo['SP8']))
    },
    'SP5': {
        'SP2': km_a_minutos(haversine(*coordenadas_geo['SP5'], *coordenadas_geo['SP2'])),
        'SP4': km_a_minutos(haversine(*coordenadas_geo['SP5'], *coordenadas_geo['SP4']))
    },
    'SP6': {
        'SP3': km_a_minutos(haversine(*coordenadas_geo['SP6'], *coordenadas_geo['SP3'])),
        'M6': km_a_minutos(haversine(*coordenadas_geo['SP6'], *coordenadas_geo['M6'])),
        'M4': km_a_minutos(haversine(*coordenadas_geo['SP6'], *coordenadas_geo['M4'])),
        'SP7': km_a_minutos(haversine(*coordenadas_geo['SP6'], *coordenadas_geo['SP7']))
    },
    'SP7': {
        'SP6': km_a_minutos(haversine(*coordenadas_geo['SP7'], *coordenadas_geo['SP6'])),
        'SP8': km_a_minutos(haversine(*coordenadas_geo['SP7'], *coordenadas_geo['SP8'])),
        'M9': km_a_minutos(haversine(*coordenadas_geo['SP7'], *coordenadas_geo['M9']))
    },
    'SP8': {
        'SP4': km_a_minutos(haversine(*coordenadas_geo['SP8'], *coordenadas_geo['SP4'])),
        'SP7': km_a_minutos(haversine(*coordenadas_geo['SP8'], *coordenadas_geo['SP7'])),
        'M9': km_a_minutos(haversine(*coordenadas_geo['SP8'], *coordenadas_geo['M9']))
    },
    'M8': {
        'M2': km_a_minutos(haversine(*coordenadas_geo['M8'], *coordenadas_geo['M2'])),
        'M10': km_a_minutos(haversine(*coordenadas_geo['M8'], *coordenadas_geo['M10'])),
        'U4': km_a_minutos(haversine(*coordenadas_geo['M8'], *coordenadas_geo['U4'])),
        'U3': km_a_minutos(haversine(*coordenadas_geo['M8'], *coordenadas_geo['U3'])),
        'Auditorio_Zinser': km_a_minutos(haversine(*coordenadas_geo['M8'], *coordenadas_geo['Auditorio_Zinser'])),
    },
    'M9': {
        'SP7': km_a_minutos(haversine(*coordenadas_geo['M9'], *coordenadas_geo['SP7'])),
        'SP8': km_a_minutos(haversine(*coordenadas_geo['M9'], *coordenadas_geo['SP8'])),
        'M4': km_a_minutos(haversine(*coordenadas_geo['M9'], *coordenadas_geo['M4'])),
        'M10': km_a_minutos(haversine(*coordenadas_geo['M9'], *coordenadas_geo['M10'])),
    },
    'M10': {
        'M8': km_a_minutos(haversine(*coordenadas_geo['M10'], *coordenadas_geo['M8'])),
        'M9': km_a_minutos(haversine(*coordenadas_geo['M10'], *coordenadas_geo['M9'])),
        'VT': km_a_minutos(haversine(*coordenadas_geo['M10'], *coordenadas_geo['VT'])),
        'U4': km_a_minutos(haversine(*coordenadas_geo['M10'], *coordenadas_geo['U4'])),
        'U3': km_a_minutos(haversine(*coordenadas_geo['M10'], *coordenadas_geo['U3'])),
        'Estacionamiento1': km_a_minutos(haversine(*coordenadas_geo['M10'], *coordenadas_geo['Estacionamiento1'])),
        'Auditorio_Zinser': km_a_minutos(haversine(*coordenadas_geo['M10'], *coordenadas_geo['Auditorio_Zinser'])),
    },
    'VT': {
        'Veterinaria': km_a_minutos(haversine(*coordenadas_geo['VT'], *coordenadas_geo['Veterinaria'])),
        'M10': km_a_minutos(haversine(*coordenadas_geo['VT'], *coordenadas_geo['M10'])),
        'Estacionamiento1': km_a_minutos(haversine(*coordenadas_geo['VT'], *coordenadas_geo['Estacionamiento1'])),
    },
    'Veterinaria': {
        'VT': km_a_minutos(haversine(*coordenadas_geo['Veterinaria'], *coordenadas_geo['VT']))
    },
    'U1': {
          'T2': km_a_minutos(haversine(*coordenadas_geo['U1'], *coordenadas_geo['T2'])),
          'U2': km_a_minutos(haversine(*coordenadas_geo['U1'], *coordenadas_geo['U2'])),
          'U3': km_a_minutos(haversine(*coordenadas_geo['U1'], *coordenadas_geo['U3'])),
          'Edificio_I': km_a_minutos(haversine(*coordenadas_geo['U1'], *coordenadas_geo['Edificio_I'])),
       },
    'U2': {
          'U1': km_a_minutos(haversine(*coordenadas_geo['U2'], *coordenadas_geo['U1'])),
          'Edificio_U': km_a_minutos(haversine(*coordenadas_geo['U2'], *coordenadas_geo['Edificio_U'])),
          'U4': km_a_minutos(haversine(*coordenadas_geo['U2'], *coordenadas_geo['U4'])),
          'Estacionamiento1': km_a_minutos(haversine(*coordenadas_geo['U2'], *coordenadas_geo['Estacionamiento1'])),
          'Edificio_I': km_a_minutos(haversine(*coordenadas_geo['U2'], *coordenadas_geo['Edificio_I'])),
       }, 
    'U3': {
          'U4': km_a_minutos(haversine(*coordenadas_geo['U3'], *coordenadas_geo['U4'])),
          'U1': km_a_minutos(haversine(*coordenadas_geo['U3'], *coordenadas_geo['U1'])),
          'T4': km_a_minutos(haversine(*coordenadas_geo['U3'], *coordenadas_geo['T4'])),
          'M10': km_a_minutos(haversine(*coordenadas_geo['U3'], *coordenadas_geo['M10'])),
          'M8': km_a_minutos(haversine(*coordenadas_geo['U3'], *coordenadas_geo['M8'])),
          'Auditorio_Zinser': km_a_minutos(haversine(*coordenadas_geo['U3'], *coordenadas_geo['Auditorio_Zinser'])),
       }, 
    'U4': {
          'U3': km_a_minutos(haversine(*coordenadas_geo['U4'], *coordenadas_geo['U3'])),
          'M10': km_a_minutos(haversine(*coordenadas_geo['U4'], *coordenadas_geo['M10'])),
          'M8': km_a_minutos(haversine(*coordenadas_geo['U4'], *coordenadas_geo['M8'])),
          'Estacionamiento1': km_a_minutos(haversine(*coordenadas_geo['U4'], *coordenadas_geo['Estacionamiento1'])),
          'Auditorio_Zinser': km_a_minutos(haversine(*coordenadas_geo['U4'], *coordenadas_geo['Auditorio_Zinser'])),
       }, 
    'Edificio_U': {
          'U2': km_a_minutos(haversine(*coordenadas_geo['Edificio_U'], *coordenadas_geo['U2'])),
          'U4': km_a_minutos(haversine(*coordenadas_geo['Edificio_U'], *coordenadas_geo['U4'])),
       }, 
    'T1': {
          'T2': km_a_minutos(haversine(*coordenadas_geo['T1'], *coordenadas_geo['T2'])),
          'S2': km_a_minutos(haversine(*coordenadas_geo['T1'], *coordenadas_geo['S2'])),
          'Edificio_T': km_a_minutos(haversine(*coordenadas_geo['T1'], *coordenadas_geo['Edificio_T'])),
          'EntradaC': km_a_minutos(haversine(*coordenadas_geo['T1'], *coordenadas_geo['EntradaC'])),
       }, 
    'T2': {
          'T1': km_a_minutos(haversine(*coordenadas_geo['T2'], *coordenadas_geo['T1'])),
          'T4': km_a_minutos(haversine(*coordenadas_geo['T2'], *coordenadas_geo['T4'])),
          'U1': km_a_minutos(haversine(*coordenadas_geo['T2'], *coordenadas_geo['U1'])),
          'EntradaC': km_a_minutos(haversine(*coordenadas_geo['T2'], *coordenadas_geo['EntradaC'])),
          'Edificio_I': km_a_minutos(haversine(*coordenadas_geo['T2'], *coordenadas_geo['Edificio_I'])),
       }, 
    'T3': {
          'B3': km_a_minutos(haversine(*coordenadas_geo['T3'], *coordenadas_geo['B3'])),
          'T4': km_a_minutos(haversine(*coordenadas_geo['T3'], *coordenadas_geo['T4'])),
          'S4': km_a_minutos(haversine(*coordenadas_geo['T3'], *coordenadas_geo['S4'])),
          'Edificio_T': km_a_minutos(haversine(*coordenadas_geo['T3'], *coordenadas_geo['Edificio_T'])),
       }, 
    'T4': {
          'T3': km_a_minutos(haversine(*coordenadas_geo['T4'], *coordenadas_geo['T3'])),
          'U3': km_a_minutos(haversine(*coordenadas_geo['T4'], *coordenadas_geo['U3'])),
          'T2': km_a_minutos(haversine(*coordenadas_geo['T4'], *coordenadas_geo['T2'])),
       }, 
    'Edificio_T': {
          'T1': km_a_minutos(haversine(*coordenadas_geo['Edificio_T'], *coordenadas_geo['T1'])),
          'T3': km_a_minutos(haversine(*coordenadas_geo['Edificio_T'], *coordenadas_geo['T3'])),
          'S4': km_a_minutos(haversine(*coordenadas_geo['Edificio_T'], *coordenadas_geo['S4'])),
          'S2': km_a_minutos(haversine(*coordenadas_geo['Edificio_T'], *coordenadas_geo['S2'])),
       }, 
    'S1': {
          'S2': km_a_minutos(haversine(*coordenadas_geo['S1'], *coordenadas_geo['S2'])),
          'Edificio_S': km_a_minutos(haversine(*coordenadas_geo['S1'], *coordenadas_geo['Edificio_S'])),
          'R2': km_a_minutos(haversine(*coordenadas_geo['S1'], *coordenadas_geo['R2'])),
          'EntradaC': km_a_minutos(haversine(*coordenadas_geo['S1'], *coordenadas_geo['EntradaC'])),
       }, 
    'S2': {
          'S1': km_a_minutos(haversine(*coordenadas_geo['S2'], *coordenadas_geo['S1'])),
          'T1': km_a_minutos(haversine(*coordenadas_geo['S2'], *coordenadas_geo['T1'])),
          'Edificio_T': km_a_minutos(haversine(*coordenadas_geo['S2'], *coordenadas_geo['Edificio_T'])),
          'S4': km_a_minutos(haversine(*coordenadas_geo['S2'], *coordenadas_geo['S4'])),
          'EntradaC': km_a_minutos(haversine(*coordenadas_geo['S2'], *coordenadas_geo['EntradaC'])),
       }, 
    'S3': {
          'R4': km_a_minutos(haversine(*coordenadas_geo['S3'], *coordenadas_geo['R4'])),
          'S4': km_a_minutos(haversine(*coordenadas_geo['S3'], *coordenadas_geo['S4'])),
          'Edificio_S': km_a_minutos(haversine(*coordenadas_geo['S3'], *coordenadas_geo['Edificio_S'])),
          'B3': km_a_minutos(haversine(*coordenadas_geo['S3'], *coordenadas_geo['B3'])),
          'B1': km_a_minutos(haversine(*coordenadas_geo['S3'], *coordenadas_geo['B1'])),
       }, 
    'S4': {
          'S3': km_a_minutos(haversine(*coordenadas_geo['S4'], *coordenadas_geo['S3'])),
          'T3': km_a_minutos(haversine(*coordenadas_geo['S4'], *coordenadas_geo['T3'])),
          'Edificio_T': km_a_minutos(haversine(*coordenadas_geo['S4'], *coordenadas_geo['Edificio_T'])),
          'B3': km_a_minutos(haversine(*coordenadas_geo['S4'], *coordenadas_geo['B3'])),
          'B1': km_a_minutos(haversine(*coordenadas_geo['S4'], *coordenadas_geo['B1'])),
       }, 
    'Edificio_S': {
          'S1': km_a_minutos(haversine(*coordenadas_geo['Edificio_S'], *coordenadas_geo['S1'])),
          'S3': km_a_minutos(haversine(*coordenadas_geo['Edificio_S'], *coordenadas_geo['S3'])),
          'R2': km_a_minutos(haversine(*coordenadas_geo['Edificio_S'], *coordenadas_geo['R2'])),
          'R4': km_a_minutos(haversine(*coordenadas_geo['Edificio_S'], *coordenadas_geo['R4'])),
       }, 
    'R1': {
          'R2': km_a_minutos(haversine(*coordenadas_geo['R1'], *coordenadas_geo['R2'])),
          'Edificio_R': km_a_minutos(haversine(*coordenadas_geo['R1'], *coordenadas_geo['Edificio_R'])),
          'CF2': km_a_minutos(haversine(*coordenadas_geo['R1'], *coordenadas_geo['CF2'])),
          'Estacionamiento2': km_a_minutos(haversine(*coordenadas_geo['R1'], *coordenadas_geo['Estacionamiento2'])),
       }, 
    'R2': {
          'R1': km_a_minutos(haversine(*coordenadas_geo['R2'], *coordenadas_geo['R1'])),
          'S1': km_a_minutos(haversine(*coordenadas_geo['R2'], *coordenadas_geo['S1'])),
          'Edificio_S': km_a_minutos(haversine(*coordenadas_geo['R2'], *coordenadas_geo['Edificio_S'])),
          'R4': km_a_minutos(haversine(*coordenadas_geo['R2'], *coordenadas_geo['R4'])),
          'EntradaC': km_a_minutos(haversine(*coordenadas_geo['R2'], *coordenadas_geo['EntradaC'])),
          'Estacionamiento2': km_a_minutos(haversine(*coordenadas_geo['R2'], *coordenadas_geo['Estacionamiento2'])),
       }, 
    'R3': {
          'R4': km_a_minutos(haversine(*coordenadas_geo['R3'], *coordenadas_geo['R4'])),
          'RB': km_a_minutos(haversine(*coordenadas_geo['R3'], *coordenadas_geo['RB'])),
          'B1': km_a_minutos(haversine(*coordenadas_geo['R3'], *coordenadas_geo['B1'])),
          'Edificio_R': km_a_minutos(haversine(*coordenadas_geo['R3'], *coordenadas_geo['Edificio_R'])),
       }, 
    'R4': {
          'R3': km_a_minutos(haversine(*coordenadas_geo['R4'], *coordenadas_geo['R3'])),
          'S3': km_a_minutos(haversine(*coordenadas_geo['R4'], *coordenadas_geo['S3'])),
          'Edificio_S': km_a_minutos(haversine(*coordenadas_geo['R4'], *coordenadas_geo['Edificio_S'])),
          'R4': km_a_minutos(haversine(*coordenadas_geo['R4'], *coordenadas_geo['R4'])),
       }, 
    'Edificio_R': {
          'R3': km_a_minutos(haversine(*coordenadas_geo['Edificio_R'], *coordenadas_geo['R3'])),
          'R1': km_a_minutos(haversine(*coordenadas_geo['Edificio_R'], *coordenadas_geo['R1'])),
          'CF4': km_a_minutos(haversine(*coordenadas_geo['Edificio_R'], *coordenadas_geo['CF4'])),
          'CFR': km_a_minutos(haversine(*coordenadas_geo['Edificio_R'], *coordenadas_geo['CFR'])),
       }, 
    'CF1': {
          'CF2': km_a_minutos(haversine(*coordenadas_geo['CF1'], *coordenadas_geo['CF2'])),
          'Q2': km_a_minutos(haversine(*coordenadas_geo['CF1'], *coordenadas_geo['Q2'])),
          'CF3': km_a_minutos(haversine(*coordenadas_geo['CF1'], *coordenadas_geo['CF3'])),
          'Estacionamiento3': km_a_minutos(haversine(*coordenadas_geo['CF1'], *coordenadas_geo['Estacionamiento3'])),
       }, 
    'CF2': {
          'CF1': km_a_minutos(haversine(*coordenadas_geo['CF2'], *coordenadas_geo['CF1'])),
          'CF4': km_a_minutos(haversine(*coordenadas_geo['CF2'], *coordenadas_geo['CF4'])),
          'R1': km_a_minutos(haversine(*coordenadas_geo['CF2'], *coordenadas_geo['R1'])),
          'Estacionamiento2': km_a_minutos(haversine(*coordenadas_geo['CF2'], *coordenadas_geo['Estacionamiento2'])),
       }, 
    'CF3': {
          'Q4': km_a_minutos(haversine(*coordenadas_geo['CF3'], *coordenadas_geo['Q4'])),
          'Cafeteria_P': km_a_minutos(haversine(*coordenadas_geo['CF3'], *coordenadas_geo['Cafeteria_P'])),
          'CF1': km_a_minutos(haversine(*coordenadas_geo['CF3'], *coordenadas_geo['CF1'])),
       }, 
    'CF4': {
          'Edificio_R': km_a_minutos(haversine(*coordenadas_geo['CF4'], *coordenadas_geo['Edificio_R'])),
          'Cafeteria_P': km_a_minutos(haversine(*coordenadas_geo['CF4'], *coordenadas_geo['Cafeteria_P'])),
          'CF2': km_a_minutos(haversine(*coordenadas_geo['CF4'], *coordenadas_geo['CF2'])),
          'CFR': km_a_minutos(haversine(*coordenadas_geo['CF4'], *coordenadas_geo['CFR'])),
       },
    'CFR': {
           'Edificio_R': km_a_minutos(haversine(*coordenadas_geo['CFR'], *coordenadas_geo['Edificio_R'])),
           'RB': km_a_minutos(haversine(*coordenadas_geo['CFR'], *coordenadas_geo['RB'])),
           'CF4': km_a_minutos(haversine(*coordenadas_geo['CFR'], *coordenadas_geo['CF4'])),
       },
    'Cafeteria_P': {
          'CF3': km_a_minutos(haversine(*coordenadas_geo['Cafeteria_P'], *coordenadas_geo['CF3'])),
          'CF4': km_a_minutos(haversine(*coordenadas_geo['Cafeteria_P'], *coordenadas_geo['CF4'])),
       }, 
    'Q1': {
          'P2': km_a_minutos(haversine(*coordenadas_geo['Q1'], *coordenadas_geo['P2'])),
          'Q2': km_a_minutos(haversine(*coordenadas_geo['Q1'], *coordenadas_geo['Q2'])),
          'Q3': km_a_minutos(haversine(*coordenadas_geo['Q1'], *coordenadas_geo['Q3'])),
          'Edificio_Q': km_a_minutos(haversine(*coordenadas_geo['Q1'], *coordenadas_geo['Edificio_Q'])),
          'Edificio_P': km_a_minutos(haversine(*coordenadas_geo['Q1'], *coordenadas_geo['Edificio_P'])),
          'Estacionamiento3': km_a_minutos(haversine(*coordenadas_geo['Q1'], *coordenadas_geo['Estacionamiento3'])),
          'Sala_de_Gobierno': km_a_minutos(haversine(*coordenadas_geo['Q1'], *coordenadas_geo['Sala_de_Gobierno'])),
       }, 
    'Q2': {
          'CF1': km_a_minutos(haversine(*coordenadas_geo['Q2'], *coordenadas_geo['CF1'])),
          'Q1': km_a_minutos(haversine(*coordenadas_geo['Q2'], *coordenadas_geo['Q1'])),
          'Q4': km_a_minutos(haversine(*coordenadas_geo['Q2'], *coordenadas_geo['Q4'])),
          'Estacionamiento3': km_a_minutos(haversine(*coordenadas_geo['Q2'], *coordenadas_geo['Estacionamiento3'])),
       }, 
    'Q3': {
          'P4': km_a_minutos(haversine(*coordenadas_geo['Q3'], *coordenadas_geo['P4'])),
          'Q4': km_a_minutos(haversine(*coordenadas_geo['Q3'], *coordenadas_geo['Q4'])),
          'Ce2': km_a_minutos(haversine(*coordenadas_geo['Q3'], *coordenadas_geo['Ce2'])),
          'Edificio_Q': km_a_minutos(haversine(*coordenadas_geo['Q3'], *coordenadas_geo['Edificio_Q'])),
          'Edificio_P': km_a_minutos(haversine(*coordenadas_geo['Q3'], *coordenadas_geo['Edificio_P'])),
          
       }, 
    'Q4': {
          'Q3': km_a_minutos(haversine(*coordenadas_geo['Q4'], *coordenadas_geo['Q3'])),
          'Ce2': km_a_minutos(haversine(*coordenadas_geo['Q4'], *coordenadas_geo['Ce2'])),
          'CF3': km_a_minutos(haversine(*coordenadas_geo['Q4'], *coordenadas_geo['CF3'])),
          'Q2': km_a_minutos(haversine(*coordenadas_geo['Q4'], *coordenadas_geo['Q2'])),
       }, 
    'Edificio_Q': {
          'P4': km_a_minutos(haversine(*coordenadas_geo['Edificio_Q'], *coordenadas_geo['P4'])),
          'P2': km_a_minutos(haversine(*coordenadas_geo['Edificio_Q'], *coordenadas_geo['P2'])),
          'Q1': km_a_minutos(haversine(*coordenadas_geo['Edificio_Q'], *coordenadas_geo['Q1'])),
          'Q3': km_a_minutos(haversine(*coordenadas_geo['Edificio_Q'], *coordenadas_geo['Q3'])),
       },   
    'P1': {
          'P2': km_a_minutos(haversine(*coordenadas_geo['P1'], *coordenadas_geo['P2'])),
          'P3': km_a_minutos(haversine(*coordenadas_geo['P1'], *coordenadas_geo['P3'])),
          'V2': km_a_minutos(haversine(*coordenadas_geo['P1'], *coordenadas_geo['V2'])),
          'Ce1': km_a_minutos(haversine(*coordenadas_geo['P1'], *coordenadas_geo['Ce1'])),
          'Sala_de_Gobierno': km_a_minutos(haversine(*coordenadas_geo['P1'], *coordenadas_geo['Sala_de_Gobierno'])),
       },   
    'P2': {
          'P1': km_a_minutos(haversine(*coordenadas_geo['P2'], *coordenadas_geo['P1'])),
          'P4': km_a_minutos(haversine(*coordenadas_geo['P2'], *coordenadas_geo['P4'])),
          'Q1': km_a_minutos(haversine(*coordenadas_geo['P2'], *coordenadas_geo['Q1'])),
          'Edificio_Q': km_a_minutos(haversine(*coordenadas_geo['P2'], *coordenadas_geo['Edificio_Q'])),
          'Edificio_P': km_a_minutos(haversine(*coordenadas_geo['P2'], *coordenadas_geo['Edificio_P'])),
          'Sala_de_Gobierno': km_a_minutos(haversine(*coordenadas_geo['P2'], *coordenadas_geo['Sala_de_Gobierno'])),
       },   
    'P3': {
          'P1': km_a_minutos(haversine(*coordenadas_geo['P3'], *coordenadas_geo['P1'])),
          'P4': km_a_minutos(haversine(*coordenadas_geo['P3'], *coordenadas_geo['P4'])),
          'V2': km_a_minutos(haversine(*coordenadas_geo['P3'], *coordenadas_geo['V2'])),
          'Ce1': km_a_minutos(haversine(*coordenadas_geo['P3'], *coordenadas_geo['Ce1'])),
          'Clinica_Escuela': km_a_minutos(haversine(*coordenadas_geo['P3'], *coordenadas_geo['Clinica_Escuela'])),
       },   
    'P4': {
          'P3': km_a_minutos(haversine(*coordenadas_geo['P4'], *coordenadas_geo['P3'])),
          'Q3': km_a_minutos(haversine(*coordenadas_geo['P4'], *coordenadas_geo['Q3'])),
          'Ce2': km_a_minutos(haversine(*coordenadas_geo['P4'], *coordenadas_geo['Ce2'])),
          'Clinica_Escuela': km_a_minutos(haversine(*coordenadas_geo['P4'], *coordenadas_geo['Clinica_Escuela'])),
          'Edificio_Q': km_a_minutos(haversine(*coordenadas_geo['P4'], *coordenadas_geo['Edificio_Q'])),
          'Edificio_P': km_a_minutos(haversine(*coordenadas_geo['P4'], *coordenadas_geo['Edificio_P'])),
       },   
    'Edificio_P': {
          'Q1': km_a_minutos(haversine(*coordenadas_geo['Edificio_P'], *coordenadas_geo['Q1'])),
          'Q3': km_a_minutos(haversine(*coordenadas_geo['Edificio_P'], *coordenadas_geo['Q3'])),
          'P4': km_a_minutos(haversine(*coordenadas_geo['Edificio_P'], *coordenadas_geo['P4'])),
          'P2': km_a_minutos(haversine(*coordenadas_geo['Edificio_P'], *coordenadas_geo['P2'])),
       },   
    'Ce1': {
          'Ce3': km_a_minutos(haversine(*coordenadas_geo['Ce1'], *coordenadas_geo['Ce3'])),
          'Clinica_Escuela': km_a_minutos(haversine(*coordenadas_geo['Ce1'], *coordenadas_geo['Clinica_Escuela'])),
          'P1': km_a_minutos(haversine(*coordenadas_geo['Ce1'], *coordenadas_geo['P1'])),
          'P3': km_a_minutos(haversine(*coordenadas_geo['Ce1'], *coordenadas_geo['P3'])),
          'V4': km_a_minutos(haversine(*coordenadas_geo['Ce1'], *coordenadas_geo['V4'])),
       },   
    'Ce2': {
          'P4': km_a_minutos(haversine(*coordenadas_geo['Ce2'], *coordenadas_geo['P4'])),
          'Q3': km_a_minutos(haversine(*coordenadas_geo['Ce2'], *coordenadas_geo['Q3'])),
          'Q4': km_a_minutos(haversine(*coordenadas_geo['Ce2'], *coordenadas_geo['Q4'])),
          'Ce4': km_a_minutos(haversine(*coordenadas_geo['Ce2'], *coordenadas_geo['Ce4'])),
          'Clinica_Escuela': km_a_minutos(haversine(*coordenadas_geo['Ce2'], *coordenadas_geo['Clinica_Escuela'])),
       },   
    'Ce3': {
          'V4': km_a_minutos(haversine(*coordenadas_geo['Ce3'], *coordenadas_geo['V4'])),
          'Ce1': km_a_minutos(haversine(*coordenadas_geo['Ce3'], *coordenadas_geo['Ce1'])),
          'Ce4': km_a_minutos(haversine(*coordenadas_geo['Ce3'], *coordenadas_geo['Ce4'])),
       },   
    'Ce4': {
          'Ce3': km_a_minutos(haversine(*coordenadas_geo['Ce4'], *coordenadas_geo['Ce3'])),
          'Ce2': km_a_minutos(haversine(*coordenadas_geo['Ce4'], *coordenadas_geo['Ce2'])),
          'C1': km_a_minutos(haversine(*coordenadas_geo['Ce4'], *coordenadas_geo['C1'])),
       },   
    'Clinica_Escuela': {
          'Ce1': km_a_minutos(haversine(*coordenadas_geo['Clinica_Escuela'], *coordenadas_geo['Ce1'])),
          'Ce2': km_a_minutos(haversine(*coordenadas_geo['Clinica_Escuela'], *coordenadas_geo['Ce2'])),
          'P3': km_a_minutos(haversine(*coordenadas_geo['Clinica_Escuela'], *coordenadas_geo['P3'])),
          'P4': km_a_minutos(haversine(*coordenadas_geo['Clinica_Escuela'], *coordenadas_geo['P4'])),
       },   
    'V1': {
          'V2': km_a_minutos(haversine(*coordenadas_geo['V1'], *coordenadas_geo['V2'])),
          'XV': km_a_minutos(haversine(*coordenadas_geo['V1'], *coordenadas_geo['XV'])),
          'X2': km_a_minutos(haversine(*coordenadas_geo['V1'], *coordenadas_geo['X2'])),
          'V3': km_a_minutos(haversine(*coordenadas_geo['V1'], *coordenadas_geo['V3'])),
       },   
    'V2': {
          'V1': km_a_minutos(haversine(*coordenadas_geo['V2'], *coordenadas_geo['V1'])),
          'P1': km_a_minutos(haversine(*coordenadas_geo['V2'], *coordenadas_geo['P1'])),
          'V4': km_a_minutos(haversine(*coordenadas_geo['V2'], *coordenadas_geo['V4'])),
          'P3': km_a_minutos(haversine(*coordenadas_geo['V2'], *coordenadas_geo['P3'])),
       },   
    'V3': {
          'X4': km_a_minutos(haversine(*coordenadas_geo['V3'], *coordenadas_geo['X4'])),
          'V4': km_a_minutos(haversine(*coordenadas_geo['V3'], *coordenadas_geo['V4'])),
          'XV': km_a_minutos(haversine(*coordenadas_geo['V3'], *coordenadas_geo['XV'])),
       },   
    'V4': {
          'V3': km_a_minutos(haversine(*coordenadas_geo['V4'], *coordenadas_geo['V3'])),
          'Ce3': km_a_minutos(haversine(*coordenadas_geo['V4'], *coordenadas_geo['Ce3'])),
          'V2': km_a_minutos(haversine(*coordenadas_geo['V4'], *coordenadas_geo['V2'])),
          'Ce1': km_a_minutos(haversine(*coordenadas_geo['V4'], *coordenadas_geo['Ce1'])),
       },   
    'Edificio_V': {
          'XV': km_a_minutos(haversine(*coordenadas_geo['Edificio_V'], *coordenadas_geo['XV'])),
          'V1': km_a_minutos(haversine(*coordenadas_geo['Edificio_V'], *coordenadas_geo['V1'])),
          'V3': km_a_minutos(haversine(*coordenadas_geo['Edificio_V'], *coordenadas_geo['V3'])),
       },   
    'XV': {
          'Edificio_V': km_a_minutos(haversine(*coordenadas_geo['XV'], *coordenadas_geo['Edificio_V'])),
          'Edificio_X': km_a_minutos(haversine(*coordenadas_geo['XV'], *coordenadas_geo['Edificio_X'])),
          'Y4': km_a_minutos(haversine(*coordenadas_geo['XV'], *coordenadas_geo['Y4'])),
          'X2': km_a_minutos(haversine(*coordenadas_geo['XV'], *coordenadas_geo['X2'])),
          'X4': km_a_minutos(haversine(*coordenadas_geo['XV'], *coordenadas_geo['X4'])),
       },   
    'X1': {
          'X2': km_a_minutos(haversine(*coordenadas_geo['X1'], *coordenadas_geo['X2'])),
          'Y2': km_a_minutos(haversine(*coordenadas_geo['X1'], *coordenadas_geo['Y2'])),
          'Edificio_W': km_a_minutos(haversine(*coordenadas_geo['X1'], *coordenadas_geo['Edificio_W'])),
          'Y4': km_a_minutos(haversine(*coordenadas_geo['X1'], *coordenadas_geo['Y4'])),
          'Edificio_X': km_a_minutos(haversine(*coordenadas_geo['X1'], *coordenadas_geo['Edificio_W'])),
       },   
    'X2': {
          'X1': km_a_minutos(haversine(*coordenadas_geo['X2'], *coordenadas_geo['X1'])),
          'X4': km_a_minutos(haversine(*coordenadas_geo['X2'], *coordenadas_geo['X4'])),
          'XV': km_a_minutos(haversine(*coordenadas_geo['X2'], *coordenadas_geo['XV'])),
          'V1': km_a_minutos(haversine(*coordenadas_geo['X2'], *coordenadas_geo['V1'])),
       },   
    'X3': {
          'X4': km_a_minutos(haversine(*coordenadas_geo['X3'], *coordenadas_geo['X4'])),
          'Y4': km_a_minutos(haversine(*coordenadas_geo['X3'], *coordenadas_geo['Y4'])),
          'Y3': km_a_minutos(haversine(*coordenadas_geo['X3'], *coordenadas_geo['Y3'])),
          'Z4': km_a_minutos(haversine(*coordenadas_geo['X3'], *coordenadas_geo['Z4'])),
          'Edificio_X': km_a_minutos(haversine(*coordenadas_geo['X3'], *coordenadas_geo['Edificio_X'])),
          'Proteccion_Civil': km_a_minutos(haversine(*coordenadas_geo['X3'], *coordenadas_geo['Proteccion_Civil'])),
       },   
    'X4': {
          'X3': km_a_minutos(haversine(*coordenadas_geo['X4'], *coordenadas_geo['X3'])),
          'V3': km_a_minutos(haversine(*coordenadas_geo['X4'], *coordenadas_geo['V3'])),
          'XV': km_a_minutos(haversine(*coordenadas_geo['X4'], *coordenadas_geo['XV'])),
          'X2': km_a_minutos(haversine(*coordenadas_geo['X4'], *coordenadas_geo['X2'])),
       },   
    'Edificio_X': {
          'Y4': km_a_minutos(haversine(*coordenadas_geo['Edificio_X'], *coordenadas_geo['Y4'])),
          'X1': km_a_minutos(haversine(*coordenadas_geo['Edificio_X'], *coordenadas_geo['X1'])),
          'X3': km_a_minutos(haversine(*coordenadas_geo['Edificio_X'], *coordenadas_geo['X3'])),
          'XV': km_a_minutos(haversine(*coordenadas_geo['Edificio_X'], *coordenadas_geo['XV'])),
       },   
    'Y1': {
          'Y2': km_a_minutos(haversine(*coordenadas_geo['Y1'], *coordenadas_geo['Y2'])),
          'Y3': km_a_minutos(haversine(*coordenadas_geo['Y1'], *coordenadas_geo['Y3'])),
          'Z2': km_a_minutos(haversine(*coordenadas_geo['Y1'], *coordenadas_geo['Z2'])),
          'Edificio_Y': km_a_minutos(haversine(*coordenadas_geo['Y1'], *coordenadas_geo['Edificio_Y'])),
          'Edificio_W': km_a_minutos(haversine(*coordenadas_geo['Y1'], *coordenadas_geo['Edificio_W'])),
       },   
    'Y2': {
          'Y1': km_a_minutos(haversine(*coordenadas_geo['Y2'], *coordenadas_geo['Y1'])),
          'Edificio_W': km_a_minutos(haversine(*coordenadas_geo['Y2'], *coordenadas_geo['Edificio_W'])),
          'Y4': km_a_minutos(haversine(*coordenadas_geo['Y2'], *coordenadas_geo['Y4'])),
          'X1': km_a_minutos(haversine(*coordenadas_geo['Y2'], *coordenadas_geo['X1'])),
          'Edificio_N': km_a_minutos(haversine(*coordenadas_geo['Y2'], *coordenadas_geo['Edificio_N'])),
       },   
    'Y3': {
          'Y4': km_a_minutos(haversine(*coordenadas_geo['Y3'], *coordenadas_geo['Y4'])),
          'Y1': km_a_minutos(haversine(*coordenadas_geo['Y3'], *coordenadas_geo['Y1'])),
          'Z2': km_a_minutos(haversine(*coordenadas_geo['Y3'], *coordenadas_geo['Z2'])),
          'Z4': km_a_minutos(haversine(*coordenadas_geo['Y3'], *coordenadas_geo['Z4'])),
          'EntradaB': km_a_minutos(haversine(*coordenadas_geo['Y3'], *coordenadas_geo['EntradaB'])),
          'Edificio_Y': km_a_minutos(haversine(*coordenadas_geo['Y3'], *coordenadas_geo['Edificio_Y'])),
          'Auditorio_Ochoa': km_a_minutos(haversine(*coordenadas_geo['Y3'], *coordenadas_geo['Auditorio_Ochoa'])),
          'Proteccion_Civil': km_a_minutos(haversine(*coordenadas_geo['Y3'], *coordenadas_geo['Proteccion_Civil'])),
       },   
    'Y4': {
          'X3': km_a_minutos(haversine(*coordenadas_geo['Y4'], *coordenadas_geo['X3'])),
          'X1': km_a_minutos(haversine(*coordenadas_geo['Y4'], *coordenadas_geo['X1'])),
          'Y3': km_a_minutos(haversine(*coordenadas_geo['Y4'], *coordenadas_geo['Y3'])),
          'Y2': km_a_minutos(haversine(*coordenadas_geo['Y4'], *coordenadas_geo['Y2'])),
          'Edificio_X': km_a_minutos(haversine(*coordenadas_geo['Y4'], *coordenadas_geo['Edificio_X'])),
          'Proteccion_Civil': km_a_minutos(haversine(*coordenadas_geo['Y4'], *coordenadas_geo['Proteccion_Civil'])),
       },   
    'Edificio_Y': {
          'Y1': km_a_minutos(haversine(*coordenadas_geo['Edificio_Y'], *coordenadas_geo['Y1'])),
          'Y3': km_a_minutos(haversine(*coordenadas_geo['Edificio_Y'], *coordenadas_geo['Y3'])),
          'Z2': km_a_minutos(haversine(*coordenadas_geo['Edificio_Y'], *coordenadas_geo['Z2'])),
          'Edificio_Z': km_a_minutos(haversine(*coordenadas_geo['Edificio_Y'], *coordenadas_geo['Edificio_Z'])),
       },   
    'Z1': {
          'Z2': km_a_minutos(haversine(*coordenadas_geo['Z1'], *coordenadas_geo['Z2'])),
          'Z3': km_a_minutos(haversine(*coordenadas_geo['Z1'], *coordenadas_geo['Z3'])),
          'Bufete_Juridico': km_a_minutos(haversine(*coordenadas_geo['Z1'], *coordenadas_geo['Bufete_Juridico'])),
          'Auditorio_Ochoa': km_a_minutos(haversine(*coordenadas_geo['Z1'], *coordenadas_geo['Auditorio_Ochoa'])),
       },   
    'Z2': {
          'Z1': km_a_minutos(haversine(*coordenadas_geo['Z2'], *coordenadas_geo['Z1'])),
          'Z4': km_a_minutos(haversine(*coordenadas_geo['Z2'], *coordenadas_geo['Z4'])),
          'Y1': km_a_minutos(haversine(*coordenadas_geo['Z2'], *coordenadas_geo['Y1'])),
          'Y3': km_a_minutos(haversine(*coordenadas_geo['Z2'], *coordenadas_geo['Y3'])),
          'EntradaB': km_a_minutos(haversine(*coordenadas_geo['Z2'], *coordenadas_geo['EntradaB'])),
          'Edificio_Z': km_a_minutos(haversine(*coordenadas_geo['Z2'], *coordenadas_geo['Edificio_Z'])),
       },   
    'Z3': {
          'Z1': km_a_minutos(haversine(*coordenadas_geo['Z3'], *coordenadas_geo['Z1'])),
          'Z4': km_a_minutos(haversine(*coordenadas_geo['Z3'], *coordenadas_geo['Z4'])),
          'Bufete_Juridico': km_a_minutos(haversine(*coordenadas_geo['Z3'], *coordenadas_geo['Bufete_Juridico'])),
          'Proteccion_Civil': km_a_minutos(haversine(*coordenadas_geo['Z3'], *coordenadas_geo['Proteccion_Civil'])),
       },   
    'Z4': {
          'Z3': km_a_minutos(haversine(*coordenadas_geo['Z4'], *coordenadas_geo['Z3'])),
          'Z2': km_a_minutos(haversine(*coordenadas_geo['Z4'], *coordenadas_geo['Z2'])),
          'X3': km_a_minutos(haversine(*coordenadas_geo['Z4'], *coordenadas_geo['X3'])),
          'Edificio_Z': km_a_minutos(haversine(*coordenadas_geo['Z4'], *coordenadas_geo['Edificio_Z'])),
          'Auditorio_Ochoa': km_a_minutos(haversine(*coordenadas_geo['Z4'], *coordenadas_geo['Auditorio_Ochoa'])),
          'Proteccion_Civil': km_a_minutos(haversine(*coordenadas_geo['Z4'], *coordenadas_geo['Proteccion_Civil'])),
       },   
    'Edificio_Z': {
          'Edificio_Y': km_a_minutos(haversine(*coordenadas_geo['Edificio_Z'], *coordenadas_geo['Edificio_Y'])),
          'Z4': km_a_minutos(haversine(*coordenadas_geo['Edificio_Z'], *coordenadas_geo['Z4'])),
          'Z1': km_a_minutos(haversine(*coordenadas_geo['Edificio_Z'], *coordenadas_geo['Z1'])),
          'Y3': km_a_minutos(haversine(*coordenadas_geo['Edificio_Z'], *coordenadas_geo['Y3'])),
       },   
    'Edificio_W': {
          'Y2': km_a_minutos(haversine(*coordenadas_geo['Edificio_W'], *coordenadas_geo['Y2'])),
          'Edificio_N': km_a_minutos(haversine(*coordenadas_geo['Edificio_W'], *coordenadas_geo['Edificio_N'])),
          'X1': km_a_minutos(haversine(*coordenadas_geo['Edificio_W'], *coordenadas_geo['X1'])),
       },   
    'Edificio_N': {
          'Edificio_W': km_a_minutos(haversine(*coordenadas_geo['Edificio_N'], *coordenadas_geo['Edificio_W'])),
       },
    'Edificio_I': {
           'U1': km_a_minutos(haversine(*coordenadas_geo['Edificio_I'], *coordenadas_geo['U1'])),
           'U2': km_a_minutos(haversine(*coordenadas_geo['Edificio_I'], *coordenadas_geo['U2'])),
           'T2': km_a_minutos(haversine(*coordenadas_geo['Edificio_I'], *coordenadas_geo['T2'])),
           'EntradaC': km_a_minutos(haversine(*coordenadas_geo['Edificio_I'], *coordenadas_geo['EntradaC'])),
       }, 
    'Estacionamiento1': {
           'VT': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento1'], *coordenadas_geo['VT'])),
           'M10': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento2'], *coordenadas_geo['M10'])),
           'U4': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento2'], *coordenadas_geo['U4'])),
           'U2': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento2'], *coordenadas_geo['U2'])),
       },
    'Estacionamiento2': {
           'CF2': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento2'], *coordenadas_geo['CF2'])),
           'R1': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento2'], *coordenadas_geo['R1'])),
           'R2': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento2'], *coordenadas_geo['R2'])),
       },
    'Estacionamiento3': {
           'Q1': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento3'], *coordenadas_geo['Q1'])),
           'Q2': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento3'], *coordenadas_geo['Q2'])),
           'CF1': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento3'], *coordenadas_geo['CF1'])),
       },
    'Estacionamiento4': {
           'EntradaA': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento4'], *coordenadas_geo['EntradaA'])),
           'C_Acuatico': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento4'], *coordenadas_geo['C_Acuatico'])),
       },
    'Estacionamiento5': {
           'EntradaA': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento5'], *coordenadas_geo['EntradaA'])),
           'Gimnasio': km_a_minutos(haversine(*coordenadas_geo['Estacionamiento5'], *coordenadas_geo['Gimnasio'])),
       },
    'Bufete_Juridico': {
           'Z1': km_a_minutos(haversine(*coordenadas_geo['Bufete_Juridico'], *coordenadas_geo['Z1'])),
           'Z3': km_a_minutos(haversine(*coordenadas_geo['Bufete_Juridico'], *coordenadas_geo['Z3'])),
       },
    'Auditorio_Ochoa': {
           'Z4': km_a_minutos(haversine(*coordenadas_geo['Auditorio_Ochoa'], *coordenadas_geo['Z4'])),
           'Z1': km_a_minutos(haversine(*coordenadas_geo['Auditorio_Ochoa'], *coordenadas_geo['Z1'])),
           'Y3': km_a_minutos(haversine(*coordenadas_geo['Auditorio_Ochoa'], *coordenadas_geo['Y3'])),
       },
    'Auditorio_Zinser': {
           'M8': km_a_minutos(haversine(*coordenadas_geo['Auditorio_Zinser'], *coordenadas_geo['M8'])),
           'M10': km_a_minutos(haversine(*coordenadas_geo['Auditorio_Zinser'], *coordenadas_geo['M10'])),
           'B3': km_a_minutos(haversine(*coordenadas_geo['Auditorio_Zinser'], *coordenadas_geo['B3'])),
           'U3': km_a_minutos(haversine(*coordenadas_geo['Auditorio_Zinser'], *coordenadas_geo['U3'])),
           'U4': km_a_minutos(haversine(*coordenadas_geo['Auditorio_Zinser'], *coordenadas_geo['U4'])),
       },
    'Edificio_J': {
           'CR': km_a_minutos(haversine(*coordenadas_geo['Edificio_J'], *coordenadas_geo['CR'])),
           'RB': km_a_minutos(haversine(*coordenadas_geo['Edificio_J'], *coordenadas_geo['RB'])),
           'Edificio_H': km_a_minutos(haversine(*coordenadas_geo['Edificio_J'], *coordenadas_geo['Edificio_H'])),
       },
    'Edificio_H': {
           'Edificio_J': km_a_minutos(haversine(*coordenadas_geo['Edificio_H'], *coordenadas_geo['Edificio_J'])),
       },
    'Sala_de_Gobierno': {
           'P1': km_a_minutos(haversine(*coordenadas_geo['Sala_de_Gobierno'], *coordenadas_geo['P1'])),
           'P2': km_a_minutos(haversine(*coordenadas_geo['Sala_de_Gobierno'], *coordenadas_geo['P2'])),
           'Q1': km_a_minutos(haversine(*coordenadas_geo['Sala_de_Gobierno'], *coordenadas_geo['Q1'])),
       },  
    'CMID': {
           'GG': km_a_minutos(haversine(*coordenadas_geo['CMID'], *coordenadas_geo['GG'])),
       },
    'GG': {
           'CMID': km_a_minutos(haversine(*coordenadas_geo['GG'], *coordenadas_geo['CMID'])),
           'Gimnasio': km_a_minutos(haversine(*coordenadas_geo['GG'], *coordenadas_geo['Gimnasio'])),
           'G1': km_a_minutos(haversine(*coordenadas_geo['GG'], *coordenadas_geo['G1'])),
           'L1': km_a_minutos(haversine(*coordenadas_geo['GG'], *coordenadas_geo['L1'])),
           'L3': km_a_minutos(haversine(*coordenadas_geo['GG'], *coordenadas_geo['L3'])),
       },
    'Auditorio_CASA': {
           'L5': km_a_minutos(haversine(*coordenadas_geo['Auditorio_CASA'], *coordenadas_geo['L5'])),
           'F2': km_a_minutos(haversine(*coordenadas_geo['Auditorio_CASA'], *coordenadas_geo['F2'])),
           
       },
    'RadioUDG': {
           'L5': km_a_minutos(haversine(*coordenadas_geo['RadioUDG'], *coordenadas_geo['L5'])),
           'L6': km_a_minutos(haversine(*coordenadas_geo['RadioUDG'], *coordenadas_geo['L6'])),
           'Auditorio_CASA': km_a_minutos(haversine(*coordenadas_geo['RadioUDG'], *coordenadas_geo['Auditorio_CASA'])),
       },
    'Proteccion_Civil': {
           'Z3': km_a_minutos(haversine(*coordenadas_geo['Proteccion_Civil'], *coordenadas_geo['Z3'])),
           'Z4': km_a_minutos(haversine(*coordenadas_geo['Proteccion_Civil'], *coordenadas_geo['Z4'])),
           'Y3': km_a_minutos(haversine(*coordenadas_geo['Proteccion_Civil'], *coordenadas_geo['Y3'])),
           'Y4': km_a_minutos(haversine(*coordenadas_geo['Proteccion_Civil'], *coordenadas_geo['Y4'])),
           'X3': km_a_minutos(haversine(*coordenadas_geo['Proteccion_Civil'], *coordenadas_geo['X3'])),
       },


    
    #   '': {
    #       'Destino': km_a_minutos(haversine(*coordenadas_geo['Inicio'], *coordenadas_geo['Destino'])),
    #   },   
    
}

# Algoritmo de Dijkstra
def dijkstra(graph, start, end):
    queue = [(0, start)]
    distances = {start: 0}
    previous = {start: None}
    visited = set()

    while queue:
        current_distance, current_node = heapq.heappop(queue)
        if current_node in visited:
            continue
        visited.add(current_node)
        if current_node == end:
            break

        for neighbor, weight in graph[current_node].items():
            distance = current_distance + weight
            if neighbor not in distances or distance < distances[neighbor]:
                distances[neighbor] = distance
                previous[neighbor] = current_node
                heapq.heappush(queue, (distance, neighbor))

    path = []
    current_node = end
    while current_node is not None:
        path.append(current_node)
        current_node = previous.get(current_node)
    return path[::-1], distances.get(end, float('inf'))


def generar_json_para_flutter():
    # Juntamos toda tu información
    datos = {
        "coordenadas_geo": coordenadas_geo,
        "coordenadas_pix": coordenadas_pix,
        "conexiones": graph  # Asegúrate de que tu diccionario de rutas se llame 'graph'
    }
    
    # Obtenemos la ruta donde se guardará
    ruta_archivo = os.path.join(os.getcwd(), "campus_data.json")
    
    # Creamos el archivo JSON
    with open(ruta_archivo, "w", encoding="utf-8") as f:
        json.dump(datos, f, indent=4, ensure_ascii=False)
        
    print("--------------------------------------------------")
    print("¡ÉXITO! El archivo se generó correctamente en esta ruta:")
    print(ruta_archivo)
    print("--------------------------------------------------")

generar_json_para_flutter()
    
