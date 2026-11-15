"""Leitura contínua de uma webcam USB em thread própria.

Com várias câmeras em rodízio, uma câmera fica alguns segundos sem ser lida
enquanto as outras são processadas. Sem esta classe, o `read()` devolvia
quadros antigos acumulados no driver. Aqui uma thread chama `grab()` sem
parar (só retira o quadro do driver, sem decodificar o JPEG, o que é barato)
e decodifica apenas quando o laço principal pede um quadro. Assim o quadro
processado é sempre o mais recente, com o instante real da captura.
"""
import threading
import time

from camera import abrir_camera


FALHAS_PARA_REABRIR = 40   # ~2 s sem quadro: câmera desconectada ou travada
ESPERA_REABRIR_S = 3.0


class CameraContinua:
    def __init__(self, fonte: int | str, id_camera: int):
        self.fonte = fonte
        self.id_camera = id_camera
        self.captura = abrir_camera(fonte)
        self._pedido = threading.Event()
        self._pronto = threading.Event()
        self._quadro = (False, None, 0.0)
        self._ativa = self.captura.isOpened()
        self._thread = threading.Thread(target=self._laco, daemon=True,
                                        name=f"camera-{id_camera}")
        if self._ativa:
            self._thread.start()

    def aberta(self) -> bool:
        return self._ativa

    def _laco(self) -> None:
        falhas = 0
        while self._ativa:
            ok = self.captura.grab()
            instante = time.time()
            if not ok:
                falhas += 1
                time.sleep(0.05)
                if self._pedido.is_set() and falhas > 20:
                    self._quadro = (False, None, instante)
                    self._pedido.clear()
                    self._pronto.set()
                if falhas >= FALHAS_PARA_REABRIR:
                    self._reabrir()
                    falhas = 0
                continue
            falhas = 0
            if self._pedido.is_set():
                ok, frame = self.captura.retrieve()
                self._quadro = (ok, frame, instante)
                self._pedido.clear()
                self._pronto.set()

    def _reabrir(self) -> None:
        """Reabre a câmera depois de um cabo mexido ou de uma queda do USB."""
        print(f"[aviso] camera {self.id_camera} sem quadros; tentando reabrir "
              f"(fonte {self.fonte})", flush=True)
        self.captura.release()
        while self._ativa:
            time.sleep(ESPERA_REABRIR_S)
            self.captura = abrir_camera(self.fonte)
            if self.captura.isOpened() and self.captura.grab():
                print(f"[info] camera {self.id_camera} reaberta", flush=True)
                return
            self.captura.release()

    def ler(self, timeout: float = 2.0):
        """Devolve (ok, quadro, instante_da_captura) do quadro mais recente."""
        if not self._ativa:
            return False, None, 0.0
        self._pronto.clear()
        self._pedido.set()
        if not self._pronto.wait(timeout):
            self._pedido.clear()
            return False, None, 0.0
        return self._quadro

    def liberar(self) -> None:
        self._ativa = False
        if self._thread.is_alive():
            self._thread.join(timeout=1)
        self.captura.release()
