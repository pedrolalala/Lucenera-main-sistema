"""SPEC-205: e-mail de recuperação de senha em português + site_url da Central no Auth do Supabase SP.

Uso: python scripts/auth_email_recuperacao_ptbr.py
Muda só 3 campos da configuração do Auth (site_url, assunto e texto do e-mail de recuperação).
"""
import json
import urllib.error
import urllib.request

from dotenv import dotenv_values

PROJECT_REF = 'bgtfrcbipuxnsexbppsh'

HTML = '''<div style="font-family:Arial,sans-serif;max-width:480px;margin:0 auto;color:#222">
<h2 style="margin-bottom:8px">Recuperar senha</h2>
<p>Recebemos um pedido para criar uma nova senha de acesso aos sistemas da Lucenera ({{ .Email }}).</p>
<p>Clique no botão abaixo para escolher a nova senha. O link vale por 1 hora e só pode ser usado uma vez.</p>
<p style="margin:24px 0"><a href="{{ .ConfirmationURL }}" style="background:#f59e0b;color:#111;padding:12px 20px;border-radius:8px;text-decoration:none;font-weight:bold">Criar nova senha</a></p>
<p style="font-size:13px;color:#666">Se você não pediu isso, ignore este e-mail. A sua senha atual continua valendo.</p>
<p style="font-size:13px;color:#666">Central de Sistemas Lucenera</p>
</div>'''

BODY = {
    'site_url': 'https://central-lucenera.pages.dev',
    'mailer_subjects_recovery': 'Lucenera — recuperar senha',
    'mailer_templates_recovery_content': HTML,
}


def main() -> None:
    token = dotenv_values('.env')['SUPABASE_ACCESS_TOKEN']
    req = urllib.request.Request(
        f'https://api.supabase.com/v1/projects/{PROJECT_REF}/config/auth',
        data=json.dumps(BODY).encode(),
        method='PATCH',
        headers={'Authorization': f'Bearer {token}', 'Content-Type': 'application/json'},
    )
    try:
        d = json.load(urllib.request.urlopen(req))
    except urllib.error.HTTPError as e:
        print('ERRO', e.code, e.read()[:500].decode(errors='replace'))
        return
    print('site_url:', d['site_url'])
    print('assunto :', d['mailer_subjects_recovery'])
    print('texto ok:', 'Criar nova senha' in d['mailer_templates_recovery_content'])


if __name__ == '__main__':
    main()
