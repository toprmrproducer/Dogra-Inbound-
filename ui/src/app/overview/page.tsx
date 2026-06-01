"use client";

import Link from 'next/link';
import { Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';

import { GitHubStarBadge } from '@/components/layout/GitHubStarBadge';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { useAuth } from '@/lib/auth';

const COST_PER_MINUTE_INR = 6;

const costProjection = [
    { minute: 1, cost: COST_PER_MINUTE_INR * 1 },
    { minute: 2, cost: COST_PER_MINUTE_INR * 2 },
    { minute: 3, cost: COST_PER_MINUTE_INR * 3 },
    { minute: 4, cost: COST_PER_MINUTE_INR * 4 },
    { minute: 5, cost: COST_PER_MINUTE_INR * 5 },
    { minute: 10, cost: COST_PER_MINUTE_INR * 10 },
];

export default function OverviewPage() {
    const { user, provider } = useAuth();
    const isOSSMode = provider !== 'stack';

    return (
        <div className="container mx-auto px-4 py-8">
            <div className="max-w-4xl mx-auto">
                {/* Welcome Card */}
                <Card className="mb-8">
                    <CardHeader>
                        <CardTitle className="text-3xl">
                            {isOSSMode ? (
                                "Welcome to RapidXAI Solution Platform"
                            ) : (
                                `Welcome${user?.displayName ? `, ${user.displayName.split(' ')[0]}` : ''}!`
                            )}
                        </CardTitle>
                        <CardDescription className="text-lg mt-2">
                            {isOSSMode ? (
                                <>
                                    Build and run inbound/outbound voice agents with realtime AI, telephony integrations, and tool orchestration.
                                </>
                            ) : (
                                "Get started with building voice AI workflows"
                            )}
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        {isOSSMode && (
                            <div className="mb-6">
                                <GitHubStarBadge label="Star us on GitHub" showCount source="overview_page" />
                            </div>
                        )}
                    </CardContent>
                </Card>

                {/* Quick Actions */}
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <Card>
                        <CardHeader>
                            <CardTitle>Create and Manage your Voice Agents</CardTitle>
                            <CardDescription>
                                Build powerful AI Voice Agents with our visual editor
                            </CardDescription>
                        </CardHeader>
                        <CardContent>
                            <Button asChild>
                                <Link href="/workflow">
                                    Go to Agents
                                </Link>
                            </Button>
                        </CardContent>
                    </Card>

                    <Card>
                        <CardHeader>
                            <CardTitle>Configure Services</CardTitle>
                            <CardDescription>
                                Set up your AI services like LLM, TTS, and STT providers
                            </CardDescription>
                        </CardHeader>
                        <CardContent>
                            <Button asChild variant="outline">
                                <Link href="/model-configurations">
                                    Configure Models
                                </Link>
                            </Button>
                        </CardContent>
                    </Card>
                </div>

                {/* Cost Tracking */}
                <Card className="mt-8">
                    <CardHeader>
                        <CardTitle>Call Cost Tracking (INR)</CardTitle>
                        <CardDescription>
                            Fixed runtime estimate: ₹{COST_PER_MINUTE_INR} per minute of call duration.
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <div className="h-64 w-full">
                            <ResponsiveContainer width="100%" height="100%">
                                <LineChart data={costProjection} margin={{ left: 12, right: 12, top: 8, bottom: 8 }}>
                                    <XAxis dataKey="minute" tickFormatter={(v) => `${v}m`} />
                                    <YAxis tickFormatter={(v) => `₹${v}`} />
                                    <Tooltip formatter={(value: number) => [`₹${value}`, 'Estimated Cost']} labelFormatter={(label) => `Minute ${label}`} />
                                    <Line type="monotone" dataKey="cost" stroke="hsl(var(--primary))" strokeWidth={2} dot />
                                </LineChart>
                            </ResponsiveContainer>
                        </div>
                    </CardContent>
                </Card>

                {/* Ops Shortcuts */}
                <Card className="mt-8">
                    <CardHeader>
                        <CardTitle>RapidXAI Operations</CardTitle>
                        <CardDescription>
                            Track tool calls, run tests, configure realtime models, and monitor run outcomes.
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <div className="flex flex-wrap gap-4">
                            <Button asChild variant="outline">
                                <Link href="/tools">
                                    Manage Tools
                                </Link>
                            </Button>
                            <Button asChild variant="outline">
                                <Link href="/usage">
                                    Track Agent Runs
                                </Link>
                            </Button>
                            <Button asChild variant="outline">
                                <Link href="/model-configurations">
                                    Realtime Model Setup
                                </Link>
                            </Button>
                            <Button asChild variant="outline">
                                <Link href="/telephony-configurations">
                                    Telephony + Test Calls
                                </Link>
                            </Button>
                        </div>
                    </CardContent>
                </Card>

                {/* Resources Section */}
                <Card className="mt-8">
                    <CardHeader>
                        <CardTitle>Resources</CardTitle>
                        <CardDescription>
                            Get help and learn more about RapidXAI and Dograh
                        </CardDescription>
                    </CardHeader>
                    <CardContent>
                        <div className="flex flex-wrap gap-4">
                            <Button asChild variant="outline">
                                <a
                                    href="https://docs.dograh.com"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                >
                                    Documentation
                                </a>
                            </Button>
                            <Button asChild variant="outline">
                                <a
                                    href="https://github.com/dograh-hq/dograh/issues"
                                    target="_blank"
                                    rel="noopener noreferrer"
                                >
                                    Report an Issue
                                </a>
                            </Button>
                        </div>
                    </CardContent>
                </Card>
            </div>
        </div>
    );
}
